import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../classifier/audio_classification.dart';
import '../classifier/audio_classifier.dart';
import '../classifier/waveform_classifier.dart';
import '../detection/shot_detector.dart';
import 'audio_preprocessor.dart';
import 'audio_service.dart';
import 'level_analysis.dart';
import 'noise_estimator.dart';

/// A loud window waiting for enough audio after its peak to be classified.
class _Candidate {
  _Candidate(this.peakSample, this.time, this.peakDbFs, this.estimatedDbSpl,
      this.backgroundDbFs);

  final int peakSample;
  final DateTime time;
  final double peakDbFs;
  final double estimatedDbSpl;
  final double? backgroundDbFs;
}

/// Orchestrates the full audio-to-detection pipeline.
///
/// Flow:
/// [AudioService] (PCM Stream)
///   → Audio Buffer (4,000 samples / 250ms)
///   → Decibel Calculation (Peak dBFS & Calibrated dB SPL)
///   → Classifier, in one of two ways:
///     - spectrogram classifiers ([EnergyClassifier], the custom TFLite
///       model): [AudioPreprocessor] log-Mel features for every window.
///     - [WaveformClassifier]s (YAMNet): only windows whose peak passes the
///       decibel gate, once ~1 s of audio around the peak is available.
///       Other windows are reported as level-only readings.
///   → Background noise: [BackgroundNoiseEstimator] over ambient windows,
///     plus each candidate's direct-to-tail ratio, attached to the
///     classification for the Detection Zone check
///   → [ShotDetector] (Decibel gate, AI threshold, detection zone, debounce,
///     latency compensation)
///   → Emits confirmed [ShotEvent]
///
/// Either way, a classification's timestamp is the time of the window's
/// peak sample, not the time processing finished.
class AudioPipeline {
  /// Creates an [AudioPipeline] with the required service components.
  AudioPipeline({
    required this.audioService,
    required this.audioPreprocessor,
    required this.audioClassifier,
    required this.shotDetector,
    double? noiseSeedDbFs,
  }) : _noise = BackgroundNoiseEstimator(seed: noiseSeedDbFs);

  /// The audio recording service providing raw PCM stream.
  final AudioService audioService;

  /// The audio preprocessor computing log-Mel spectrograms.
  final AudioPreprocessor audioPreprocessor;

  /// The AI audio classifier performing model inference.
  final AudioClassifier audioClassifier;

  /// The shot detector applying debounce, decibel gates, and thresholds.
  final ShotDetector shotDetector;

  StreamSubscription<Uint8List>? _audioSubscription;
  final StreamController<AudioClassification>
      _classificationStreamController =
      StreamController<AudioClassification>.broadcast();

  final StreamController<Object> _errorStreamController =
      StreamController<Object>.broadcast();

  final List<int> _audioBuffer = [];

  /// Wall-clock time of sample 0. Derived from when the first chunk arrived,
  /// minus that chunk's duration, so it reflects when the audio was captured
  /// rather than when it was processed.
  DateTime? _streamStart;

  /// Samples consumed into windows so far, used to place each window in time.
  int _samplesConsumed = 0;

  /// Windows are classified strictly in arrival order, so debounce decisions
  /// are never made out of sequence.
  Future<void> _windowQueue = Future<void>.value();

  /// Recent audio (scaled to -1..1) for waveform classifiers.
  /// [_history] element 0 is sample number [_historyStart].
  final List<double> _history = [];
  int _historyStart = 0;
  final List<_Candidate> _pending = [];

  final BackgroundNoiseEstimator _noise;

  /// Current background-noise estimate (dBFS): live once enough ambient audio
  /// has been heard, otherwise the calibration seed, otherwise null.
  double? get backgroundDbFs => _noise.estimate;

  /// Whether [backgroundDbFs] is measured in this session (not the seed).
  bool get backgroundIsLive => _noise.isLive;

  /// Exposes a stream of real-time classifications and decibels for UI indicators.
  Stream<AudioClassification> get classificationStream =>
      _classificationStreamController.stream;

  /// Runtime errors from the microphone stream, surfaced for status displays.
  Stream<Object> get errorStream => _errorStreamController.stream;

  WaveformClassifier? get _waveform {
    final AudioClassifier c = audioClassifier;
    return c is WaveformClassifier ? c : null;
  }

  /// Starts the pipeline and begins listening to the audio stream.
  Future<void> start() async {
    try {
      if (!audioClassifier.isReady) {
        await audioClassifier.loadModel();
      }

      _streamStart = null;
      _samplesConsumed = 0;
      _history.clear();
      _historyStart = 0;
      _pending.clear();
      _noise.reset();
      await audioService.startRecording();

      _audioSubscription = audioService.audioStream.listen(
        _onAudioDataReceived,
        onError: (Object e) {
          debugPrint('Audio stream error in pipeline: $e');
          if (!_errorStreamController.isClosed) _errorStreamController.add(e);
        },
      );
    } catch (e) {
      debugPrint('Failed to start AudioPipeline: $e');
      rethrow;
    }
  }

  void _onAudioDataReceived(Uint8List data) {
    const int sampleRate = AudioConstants.sampleRate;
    if (_streamStart == null) {
      final int chunkMicros = (data.length ~/ 2) * 1000000 ~/ sampleRate;
      _streamStart = DateTime.now().subtract(Duration(microseconds: chunkMicros));
    }
    _audioBuffer.addAll(data);

    // Each sample in PCM16 is 2 bytes.
    final int windowSamples = AudioConstants.windowSamples;
    final int requiredBytes = windowSamples * 2;
    final WaveformClassifier? waveform = _waveform;

    while (_audioBuffer.length >= requiredBytes) {
      // Extract one window of audio
      final Uint8List windowBytes =
          Uint8List.fromList(_audioBuffer.sublist(0, requiredBytes));
      _audioBuffer.removeRange(0, requiredBytes);

      // The sound happened at the peak sample, not when the window was
      // finished or classified. Place it on the sample clock.
      final int peakIndex = peakIndexFromPcm16(windowBytes);
      final int peakSample = _samplesConsumed + peakIndex;
      _samplesConsumed += windowSamples;
      final DateTime soundTime = _timeOfSample(peakSample);

      // Background as it stood before this window, so a loud window is
      // compared with the quiet before it.
      final double peakDbFs = peakDbFsFromPcm16(windowBytes);
      final double? background = _noise.estimate;
      _noise.add(peakDbFs,
          isCandidate: peakDbFs >= shotDetector.config.minPeakDbFs);

      if (waveform != null) {
        _onWaveformWindow(waveform, windowBytes, peakSample, soundTime,
            peakDbFs, background);
      } else {
        _windowQueue = _windowQueue.then((_) => _processAudioWindow(
            windowBytes, soundTime, peakIndex, peakDbFs, background));
      }
    }
  }

  DateTime _timeOfSample(int sample) => _streamStart!.add(Duration(
      microseconds: sample * 1000000 ~/ AudioConstants.sampleRate));

  double _estimatedSpl(double peakDbFs) {
    // Calibrated estimated SPL (gunshot saturation ~162 dB SPL for 0 dBFS)
    final double nominalSpl =
        shotDetector.config.firearmProfile.nominalPeakDbSpl;
    return (nominalSpl + peakDbFs).clamp(30.0, 175.0);
  }

  void _emit(AudioClassification c) {
    if (!_classificationStreamController.isClosed) {
      _classificationStreamController.add(c);
    }
  }

  Future<void> _processAudioWindow(Uint8List windowBytes, DateTime soundTime,
      int peakIndex, double peakDbFs, double? backgroundDbFs) async {
    try {
      // 1. Decibel metrics (peak dBFS is shared with the settings meter and
      // calibration), plus the echo measurement for loud windows. Only the
      // rest of this window follows the peak, so late peaks may have none.
      final double estimatedDbSpl = _estimatedSpl(peakDbFs);
      final double? directRatio = peakDbFs >= shotDetector.config.minPeakDbFs
          ? directToTailRatioDb(pcm16ToSamples(windowBytes), peakIndex)
          : null;

      // 2. Preprocess: raw PCM bytes to normalized log-Mel spectrogram
      final Float32List features =
          audioPreprocessor.processAudioFrame(windowBytes);

      // 3. Classify: model inference
      final AudioClassification rawClassification =
          await audioClassifier.classify(features);

      final AudioClassification classification =
          rawClassification.withMeasurements(
        timestamp: soundTime,
        peakDbFs: peakDbFs,
        estimatedDbSpl: estimatedDbSpl,
        backgroundDbFs: backgroundDbFs,
        directRatioDb: directRatio,
      );

      // 4. Pass to shot detector for decibel gate, debounce & threshold checks
      shotDetector.processClassification(classification);

      // 5. Expose classification for UI
      _emit(classification);
    } catch (e) {
      debugPrint('Error processing audio window: $e');
    }
  }

  // ---- Waveform classifiers (YAMNet) ----

  void _onWaveformWindow(WaveformClassifier classifier, Uint8List windowBytes,
      int peakSample, DateTime soundTime, double peakDbFs,
      double? backgroundDbFs) {
    final double estimatedDbSpl = _estimatedSpl(peakDbFs);

    final ByteData pcm = ByteData.sublistView(windowBytes);
    for (int i = 0; i + 1 < windowBytes.length; i += 2) {
      _history.add(pcm.getInt16(i, Endian.little) / 32768.0);
    }

    // The meter keeps updating every window; the AI verdict follows later.
    _emit(AudioClassification.levelOnly(
      timestamp: soundTime,
      peakDbFs: peakDbFs,
      estimatedDbSpl: estimatedDbSpl,
      backgroundDbFs: backgroundDbFs,
    ));

    // Only sounds that could count are worth a model run.
    if (peakDbFs >= shotDetector.config.minPeakDbFs &&
        shotDetector.isActive &&
        !shotDetector.isPaused) {
      _pending.add(_Candidate(
          peakSample, soundTime, peakDbFs, estimatedDbSpl, backgroundDbFs));
    }

    _classifyReady(classifier, flush: false);
    _trimHistory(classifier);
  }

  /// Queues every candidate whose clip is complete. With [flush], queues all
  /// of them, padding missing audio with silence.
  void _classifyReady(WaveformClassifier classifier, {required bool flush}) {
    final int historyEnd = _historyStart + _history.length;
    while (_pending.isNotEmpty) {
      final _Candidate c = _pending.first;
      final int start = c.peakSample - classifier.preRollSamples;
      if (!flush && start + classifier.inputSamples > historyEnd) break;
      _pending.removeAt(0);

      final Float32List clip = Float32List(classifier.inputSamples);
      for (int i = 0; i < clip.length; i++) {
        final int idx = start + i - _historyStart;
        if (idx >= 0 && idx < _history.length) clip[i] = _history[idx];
      }
      _windowQueue = _windowQueue
          .then((_) => _classifyCandidate(classifier, clip, c));
    }
  }

  void _trimHistory(WaveformClassifier classifier) {
    final int historyEnd = _historyStart + _history.length;
    // A future window's peak is at or after historyEnd.
    int keepFrom = historyEnd - classifier.preRollSamples;
    if (_pending.isNotEmpty) {
      keepFrom = math.min(
          keepFrom, _pending.first.peakSample - classifier.preRollSamples);
    }
    final int drop = keepFrom - _historyStart;
    if (drop > 0) {
      _history.removeRange(0, math.min(drop, _history.length));
      _historyStart += drop;
    }
  }

  Future<void> _classifyCandidate(
      WaveformClassifier classifier, Float32List clip, _Candidate c) async {
    try {
      final AudioClassification raw = await classifier.classifyWaveform(clip);
      final AudioClassification classification = raw.withMeasurements(
        timestamp: c.time,
        peakDbFs: c.peakDbFs,
        estimatedDbSpl: c.estimatedDbSpl,
        backgroundDbFs: c.backgroundDbFs,
        // The clip holds the peak at the pre-roll position and ~575 ms after.
        directRatioDb: directToTailRatioDb(clip, classifier.preRollSamples),
      );
      shotDetector.processClassification(classification);
      _emit(classification);
    } catch (e) {
      debugPrint('Error classifying sound: $e');
    }
  }

  /// Stops audio recording and clears buffers.
  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await audioService.stopRecording();
    _audioBuffer.clear();
    // Sounds just before stopping still get a verdict, padded with silence.
    final WaveformClassifier? waveform = _waveform;
    if (waveform != null) _classifyReady(waveform, flush: true);
    // Let windows already received finish, so their events are not lost.
    await _windowQueue;
    _history.clear();
    _pending.clear();
  }

  /// Releases all pipeline resources.
  Future<void> dispose() async {
    await stop();
    await _classificationStreamController.close();
    await _errorStreamController.close();
    await audioService.dispose();
    await audioClassifier.dispose();
  }
}
