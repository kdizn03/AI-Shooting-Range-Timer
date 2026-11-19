import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import '../../models/microphone.dart';
import 'audio_service.dart';
import 'level_analysis.dart';
import 'noise_estimator.dart';

/// State of the input monitor.
enum MonitorStatus {
  /// Not running.
  idle,

  /// Requesting permission or waiting for the first window.
  starting,

  /// Receiving audio.
  listening,

  /// Microphone permission refused or blocked.
  permissionDenied,

  /// Running, but no audio has arrived recently.
  noInput,

  /// Failed to start or stream audio. See [AudioLevelMonitor.errorMessage].
  error,
}

/// One analysis window's measured peak level.
class LevelReading {
  const LevelReading(this.dbFs, this.at);

  /// Peak level in dBFS (never below [kSilenceFloorDbFs]).
  final double dbFs;

  /// When the window finished arriving.
  final DateTime at;
}

/// Live input-level monitor and calibration source.
///
/// Reads PCM from an [AudioService], splits it into the same 250 ms windows
/// the detection pipeline uses, and measures each window's peak in dBFS.
/// Every value comes from captured audio; nothing is simulated.
///
/// Notifiers are updated about four times per second. Only widgets that
/// listen to them rebuild, so the rest of the screen is left alone.
class AudioLevelMonitor {
  /// Creates a monitor. [createAudio] is called on first start, so the
  /// microphone is not touched until monitoring is requested.
  AudioLevelMonitor({
    required AudioService Function() createAudio,
    int historyWindows = 80,
    DateTime Function()? clock,
  })  : _createAudio = createAudio,
        _noise = BackgroundNoiseEstimator(capacity: historyWindows),
        _now = clock ?? DateTime.now;

  final AudioService Function() _createAudio;
  final DateTime Function() _now;

  AudioService? _audio;
  // Cancelled in _teardown(), which every stop and failure path calls.
  // ignore: cancel_subscriptions
  StreamSubscription<Uint8List>? _sub;
  Timer? _watchdog;
  DateTime? _lastData;
  final List<int> _buffer = <int>[];
  final BackgroundNoiseEstimator _noise;
  final StreamController<double> _windowsController =
      StreamController<double>.broadcast();
  bool _disposed = false;

  /// Latest window's level, or `null` when not listening.
  final ValueNotifier<LevelReading?> level = ValueNotifier<LevelReading?>(null);

  /// Background estimate: 10th percentile of recent ambient windows (loud
  /// events excluded, see [BackgroundNoiseEstimator]), or `null`.
  final ValueNotifier<double?> backgroundDbFs = ValueNotifier<double?>(null);

  /// Current state.
  final ValueNotifier<MonitorStatus> status =
      ValueNotifier<MonitorStatus>(MonitorStatus.idle);

  /// Human-readable detail for [MonitorStatus.error] and the like.
  String? errorMessage;

  /// Every window's dBFS value as it arrives.
  Stream<double> get windows => _windowsController.stream;

  /// The input actually being measured, once started.
  MicRoute? get route => _audio?.route;

  /// Whether the microphone is currently open.
  bool get isRunning => _sub != null;

  /// Opens the microphone and begins measuring.
  Future<void> start() async {
    if (_disposed || isRunning || status.value == MonitorStatus.starting) {
      return;
    }
    errorMessage = null;
    status.value = MonitorStatus.starting;
    final AudioService audio = _audio ??= _createAudio();
    try {
      if (!await audio.requestPermission()) {
        _fail(MonitorStatus.permissionDenied,
            'Microphone permission was denied.');
        return;
      }
      await audio.startRecording();
      _lastData = _now();
      _sub = audio.audioStream.listen(
        _onData,
        onError: (Object e) => _fail(
            MonitorStatus.error, 'Microphone stream error: $e'),
        onDone: () {
          if (isRunning) {
            _fail(MonitorStatus.noInput, 'The microphone stream ended.');
          }
        },
      );
      _watchdog = Timer.periodic(const Duration(seconds: 1), _checkInput);
    } on MicrophonePermissionDeniedException catch (e) {
      _fail(MonitorStatus.permissionDenied, e.message);
    } catch (e) {
      _fail(MonitorStatus.error, 'Could not start the microphone: $e');
    }
  }

  /// Closes the microphone and clears readings.
  Future<void> stop() async {
    await _teardown();
    _noise.reset();
    level.value = null;
    backgroundDbFs.value = null;
    status.value = MonitorStatus.idle;
  }

  /// Collects window levels for [duration], starting the monitor if needed.
  ///
  /// If this call started the monitor, it stops it again afterwards. Failure
  /// states set by a refused or failed start are kept, so the caller can
  /// read [status] and [errorMessage].
  Future<List<double>> collectFor(Duration duration) async {
    final bool startedHere = !isRunning;
    final List<double> collected = <double>[];
    final StreamSubscription<double> sub = windows.listen(collected.add);
    try {
      if (startedHere) await start();
      if (isRunning) await Future<void>.delayed(duration);
    } finally {
      await sub.cancel();
      if (startedHere) {
        await _teardown();
        if (status.value == MonitorStatus.starting ||
            status.value == MonitorStatus.listening ||
            status.value == MonitorStatus.noInput) {
          status.value = MonitorStatus.idle;
        }
        level.value = null;
        backgroundDbFs.value = null;
      }
    }
    return collected;
  }

  /// Runs a background-noise calibration for [duration].
  ///
  /// Returns a suggestion for the user to review. It is never applied
  /// automatically.
  Future<CalibrationOutcome> calibrate({
    Duration duration = const Duration(seconds: 6),
  }) async {
    final List<double> windowsSeen = await collectFor(duration);
    switch (status.value) {
      case MonitorStatus.permissionDenied:
        return CalibrationOutcome.failed(CalibrationIssue.permissionDenied,
            message: errorMessage);
      case MonitorStatus.error:
        return CalibrationOutcome.failed(CalibrationIssue.error,
            message: errorMessage);
      default:
        return analyzeCalibration(windowsSeen);
    }
  }

  /// Releases everything, including the microphone resource.
  Future<void> dispose() async {
    if (_disposed) return;
    await stop();
    _disposed = true;
    await _windowsController.close();
    await _audio?.dispose();
    level.dispose();
    backgroundDbFs.dispose();
    status.dispose();
  }

  void _onData(Uint8List data) {
    _buffer.addAll(data);
    final int windowBytes = AudioConstants.windowSamples * 2;
    while (_buffer.length >= windowBytes) {
      final Uint8List window =
          Uint8List.fromList(_buffer.sublist(0, windowBytes));
      _buffer.removeRange(0, windowBytes);

      final double db = peakDbFsFromPcm16(window);
      _lastData = _now();
      _noise.add(db);

      level.value = LevelReading(db, _lastData!);
      backgroundDbFs.value = _noise.estimate;
      if (status.value != MonitorStatus.listening) {
        status.value = MonitorStatus.listening;
      }
      if (!_windowsController.isClosed) _windowsController.add(db);
    }
  }

  void _checkInput(Timer _) {
    final DateTime? last = _lastData;
    if (!isRunning || last == null) return;
    if (_now().difference(last) > const Duration(seconds: 2)) {
      level.value = null;
      if (status.value == MonitorStatus.listening) {
        errorMessage = 'No audio has arrived for over 2 seconds.';
        status.value = MonitorStatus.noInput;
      }
    }
  }

  void _fail(MonitorStatus failure, String message) {
    errorMessage = message;
    status.value = failure;
    unawaited(_teardown());
  }

  Future<void> _teardown() async {
    _watchdog?.cancel();
    _watchdog = null;
    final StreamSubscription<Uint8List>? sub = _sub;
    _sub = null;
    _buffer.clear();
    await sub?.cancel();
    final AudioService? audio = _audio;
    if (audio != null && audio.isRecording) {
      try {
        await audio.stopRecording();
      } catch (e) {
        debugPrint('Failed to stop level monitor recording: $e');
      }
    }
  }
}
