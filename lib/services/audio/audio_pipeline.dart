import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../classifier/audio_classification.dart';
import '../classifier/audio_classifier.dart';
import '../detection/shot_detector.dart';
import 'audio_preprocessor.dart';
import 'audio_service.dart';

/// Orchestrates the full audio-to-detection pipeline.
///
/// Flow:
/// [AudioService] (PCM Stream)
///   → Audio Buffer (4,000 samples / 250ms)
///   → Decibel Calculation (Peak dBFS & Calibrated dB SPL)
///   → [AudioPreprocessor] (2D Log-Mel Spectrogram)
///   → [AudioClassifier] (TFLite / Fallback inference)
///   → [ShotDetector] (Decibel gate, AI threshold, debounce, latency compensation)
///   → Emits confirmed [ShotEvent]
class AudioPipeline {
  /// Creates an [AudioPipeline] with the required service components.
  AudioPipeline({
    required this.audioService,
    required this.audioPreprocessor,
    required this.audioClassifier,
    required this.shotDetector,
  });

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

  final List<int> _audioBuffer = [];

  /// Exposes a stream of real-time classifications and decibels for UI indicators.
  Stream<AudioClassification> get classificationStream =>
      _classificationStreamController.stream;

  /// Starts the pipeline and begins listening to the audio stream.
  Future<void> start() async {
    try {
      if (!audioClassifier.isReady) {
        await audioClassifier.loadModel();
      }

      await audioService.startRecording();

      _audioSubscription = audioService.audioStream.listen(
        _onAudioDataReceived,
        onError: (Object e) {
          debugPrint('Audio stream error in pipeline: $e');
        },
      );
    } catch (e) {
      debugPrint('Failed to start AudioPipeline: $e');
      rethrow;
    }
  }

  void _onAudioDataReceived(Uint8List data) {
    _audioBuffer.addAll(data);

    // Each sample in PCM16 is 2 bytes.
    final int requiredBytes = AudioConstants.windowSamples * 2;

    while (_audioBuffer.length >= requiredBytes) {
      // Extract one window of audio
      final Uint8List windowBytes =
          Uint8List.fromList(_audioBuffer.sublist(0, requiredBytes));
      _audioBuffer.removeRange(0, requiredBytes);

      _processAudioWindow(windowBytes);
    }
  }

  Future<void> _processAudioWindow(Uint8List windowBytes) async {
    try {
      // 1. Calculate acoustic decibel metrics from raw 16-bit PCM window
      int maxAbs = 0;
      final int numSamples = windowBytes.length ~/ 2;
      final ByteData byteData = ByteData.sublistView(windowBytes);
      for (int i = 0; i < numSamples; i++) {
        final int sample = byteData.getInt16(i * 2, Endian.little);
        final int abs = sample.abs();
        if (abs > maxAbs) maxAbs = abs;
      }
      final double peakRatio = maxAbs / 32768.0;
      final double peakDbFs = peakRatio > 0.00001
          ? 20.0 * (math.log(peakRatio) / math.ln10)
          : -96.0;

      // Calibrated estimated SPL (gunshot saturation ~162 dB SPL for 0 dBFS)
      final double nominalSpl =
          shotDetector.config.firearmProfile.nominalPeakDbSpl;
      final double estimatedDbSpl =
          (nominalSpl + peakDbFs).clamp(30.0, 175.0);

      // 2. Preprocess: raw PCM bytes to normalized log-Mel spectrogram
      final Float32List features =
          audioPreprocessor.processAudioFrame(windowBytes);

      // 3. Classify: model inference
      final AudioClassification rawClassification =
          await audioClassifier.classify(features);

      final AudioClassification classification = AudioClassification(
        label: rawClassification.label,
        confidence: rawClassification.confidence,
        scores: rawClassification.scores,
        timestamp: rawClassification.timestamp,
        peakDbFs: peakDbFs,
        estimatedDbSpl: estimatedDbSpl,
      );

      // 4. Pass to shot detector for decibel gate, debounce & threshold checks
      shotDetector.processClassification(classification);

      // 5. Expose classification for UI
      if (!_classificationStreamController.isClosed) {
        _classificationStreamController.add(classification);
      }
    } catch (e) {
      debugPrint('Error processing audio window: $e');
    }
  }

  /// Stops audio recording and clears buffers.
  Future<void> stop() async {
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await audioService.stopRecording();
    _audioBuffer.clear();
  }

  /// Releases all pipeline resources.
  Future<void> dispose() async {
    await stop();
    await _classificationStreamController.close();
    await audioService.dispose();
    await audioClassifier.dispose();
  }
}
