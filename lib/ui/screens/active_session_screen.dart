import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/firearm_profile.dart';
import '../../models/shot_event.dart';
import '../../providers/session_history_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/audio/audio_pipeline.dart';
import '../../services/audio/beep_service.dart';
import '../../services/audio/mel_spectrogram_preprocessor.dart';
import '../../services/audio/record_audio_service.dart';
import '../../services/classifier/audio_classification.dart';
import '../../services/classifier/classifier_factory.dart';
import '../../services/detection/detection_config.dart';
import '../../services/detection/shot_detector.dart';
import '../widgets/mic_indicator.dart';
import '../widgets/shot_list_tile.dart';
import '../widgets/timer_display.dart';
import 'results_screen.dart';
import 'session_setup_screen.dart';

/// Active shooting session phases.
enum SessionPhase {
  /// Shooter is waiting for the starting buzzer (Standby).
  standby,

  /// Starting beep is sounding.
  beep,

  /// Timer is running and listening for shots.
  active,

  /// Session has finished.
  finished,
}

/// The main active session screen.
///
/// Features:
/// - Standby delay countdown with "STANDBY" status
/// - Visual starting beep indicator
/// - High-precision elapsed stopwatch display
/// - Real-time on-device audio pipeline or simulation mode
/// - Firearm profile & decibel thresholding
/// - Live AI classification & decibel feedback
/// - Debounced shot detection and shot event list
/// - Prominent STOP button and exit protection
class ActiveSessionScreen extends ConsumerStatefulWidget {
  /// Creates an [ActiveSessionScreen].
  const ActiveSessionScreen({
    super.key,
    this.sensitivity = 0.7,
    this.delayMode = StartDelayMode.fixed3s,
    this.isSimulation = false,
    this.firearmProfile = FirearmProfile.glock19Unsuppressed,
  });

  /// AI confidence threshold (0.0–1.0).
  final double sensitivity;

  /// Start delay before the beep sounds.
  final StartDelayMode delayMode;

  /// Whether to simulate shots instead of using the live microphone.
  final bool isSimulation;

  /// Configured firearm acoustic profile (e.g. Glock 19 Unsuppressed vs Suppressed).
  final FirearmProfile firearmProfile;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen> {
  late final Stopwatch _stopwatch;
  SessionPhase _phase = SessionPhase.standby;
  int _countdownSeconds = 0;

  Timer? _uiTimer;
  Timer? _standbyTimer;
  Timer? _mockShotTimer;

  // Real audio pipeline components
  AudioPipeline? _audioPipeline;
  ShotDetector? _shotDetector;
  StreamSubscription<ShotEvent>? _shotSubscription;
  StreamSubscription<AudioClassification>? _classificationSubscription;

  AudioClassification? _latestClassification;
  final Random _random = Random();
  final BeepService _beepService = BeepService();
  int _shotCount = 0;
  String? _pipelineErrorMessage;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initiateStandby();
    });
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
    _standbyTimer?.cancel();
    _mockShotTimer?.cancel();
    _shotSubscription?.cancel();
    _classificationSubscription?.cancel();
    _audioPipeline?.dispose();
    _shotDetector?.dispose();
    _beepService.dispose();
    super.dispose();
  }

  /// Calculates the standby delay in seconds.
  int _calculateDelaySeconds() {
    switch (widget.delayMode) {
      case StartDelayMode.instant:
        return 0;
      case StartDelayMode.fixed3s:
        return 3;
      case StartDelayMode.random2to4s:
        return 2 + _random.nextInt(3); // 2, 3, or 4 seconds
    }
  }

  void _initiateStandby() {
    final int delay = _calculateDelaySeconds();
    if (delay == 0) {
      _triggerBeepAndStart();
      return;
    }

    setState(() {
      _phase = SessionPhase.standby;
      _countdownSeconds = delay;
    });

    _standbyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _countdownSeconds--;
      });

      if (_countdownSeconds <= 0) {
        timer.cancel();
        _triggerBeepAndStart();
      }
    });
  }

  void _triggerBeepAndStart() async {
    if (!mounted) return;

    setState(() {
      _phase = SessionPhase.beep;
    });

    // Play the audible buzzer beep and trigger haptic feedback
    unawaited(_beepService.playBeep());

    // Brief visual beep duration (300ms)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _startActiveSession();
  }

  void _startActiveSession() async {
    ref
        .read(sessionProvider.notifier)
        .startSession(firearmProfile: widget.firearmProfile);
    _stopwatch.start();

    setState(() {
      _phase = SessionPhase.active;
    });

    // UI update timer (~60 FPS)
    _uiTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (mounted) {
        ref.read(sessionProvider.notifier).updateElapsed(_stopwatch.elapsed);
      }
    });

    if (widget.isSimulation) {
      _scheduleMockShot();
    } else {
      await _startLiveAudioPipeline();
    }
  }

  Future<void> _startLiveAudioPipeline() async {
    try {
      final config = DetectionConfig(
        confidenceThreshold: widget.sensitivity,
        minPeakDbFs: widget.firearmProfile.minPeakDbFs,
        firearmProfile: widget.firearmProfile,
        debounceDurationMs: DetectionConstants.defaultDebounceDurationMs,
        inferenceLatencyCompensationMs:
            TimingConstants.estimatedInferenceLatencyMs,
      );

      _shotDetector = ShotDetector(config: config);
      _shotDetector!.start(DateTime.now());

      final audioService = RecordAudioService();
      final preprocessor = MelSpectrogramPreprocessor();
      final classifier = createAudioClassifier();

      _audioPipeline = AudioPipeline(
        audioService: audioService,
        audioPreprocessor: preprocessor,
        audioClassifier: classifier,
        shotDetector: _shotDetector!,
      );

      _shotSubscription = _shotDetector!.shotStream.listen((ShotEvent shot) {
        if (!mounted) return;
        ref.read(sessionProvider.notifier).addShot(shot);
      });

      _classificationSubscription = _audioPipeline!.classificationStream.listen(
        (AudioClassification classification) {
          if (!mounted) return;
          setState(() {
            _latestClassification = classification;
          });
        },
      );

      await _audioPipeline!.start();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pipelineErrorMessage = 'Audio error ($e). Falling back to simulation.';
      });
      // Fallback to simulation mode on error
      _scheduleMockShot();
    }
  }

  void _scheduleMockShot() {
    if (!mounted || !_stopwatch.isRunning) return;

    final delay = Duration(milliseconds: 1000 + _random.nextInt(2000));
    _mockShotTimer = Timer(delay, () {
      if (!mounted || !_stopwatch.isRunning) return;

      _shotCount++;
      // Simulate realistic decibels centered on the firearm profile nominal dB
      final double nominalSpl = widget.firearmProfile.nominalPeakDbSpl;
      final double simulatedDb =
          nominalSpl + (_random.nextDouble() * 4.0 - 2.0);

      final shot = ShotEvent(
        shotNumber: _shotCount,
        elapsedTime: _stopwatch.elapsed,
        confidence: 0.85 + (_random.nextDouble() * 0.14),
        detectionTimestamp: DateTime.now(),
        peakDecibels: simulatedDb,
      );

      ref.read(sessionProvider.notifier).addShot(shot);
      _scheduleMockShot();
    });
  }

  Future<void> _stopSession() async {
    _stopwatch.stop();
    _uiTimer?.cancel();
    _standbyTimer?.cancel();
    _mockShotTimer?.cancel();

    await _shotSubscription?.cancel();
    await _classificationSubscription?.cancel();
    await _audioPipeline?.stop();
    _shotDetector?.stop();

    ref.read(sessionProvider.notifier).stopSession();
    final sessionState = ref.read(sessionProvider);

    if (sessionState.session != null) {
      await ref
          .read(sessionRepositoryProvider)
          .saveSession(sessionState.session!);
      // ignore: unused_result
      ref.refresh(sessionHistoryProvider);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (context) => ResultsScreen(
              session: sessionState.session!,
            ),
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (_phase == SessionPhase.finished) return true;

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Session?'),
        content: const Text(
          'Are you sure you want to stop this practice session? Unsaved shot progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (shouldLeave == true) {
      await _stopSession();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, dynamic result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              _phase == SessionPhase.standby ? 'Standby' : 'Active Session'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () async {
                if (await _onWillPop()) {
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        body: _phase == SessionPhase.standby
            ? _buildStandbyView()
            : _buildActiveView(sessionState),
      ),
    );
  }

  Widget _buildStandbyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amber, width: 2),
            ),
            child: const Text(
              'STANDBY',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '$_countdownSeconds',
            style: const TextStyle(
              fontSize: 72,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Get ready for the buzzer...',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${widget.firearmProfile.displayName} (${widget.firearmProfile.typicalDbRange})',
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveView(SessionState sessionState) {
    return Column(
      children: [
        if (_phase == SessionPhase.beep)
          Container(
            width: double.infinity,
            color: Colors.yellowAccent,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            child: const Text(
              'BEEP!',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 3,
              ),
            ),
          ),

        if (_pipelineErrorMessage != null)
          Container(
            color: Colors.orange.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Text(
              _pipelineErrorMessage!,
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),

        const SizedBox(height: 16),

        // Firearm Profile Badge & Live Decibel Meter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.firearmProfile.isSuppressed
                      ? Colors.blueAccent.withValues(alpha: 0.2)
                      : Colors.orangeAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: widget.firearmProfile.isSuppressed
                        ? Colors.blueAccent
                        : Colors.orangeAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.firearmProfile.isSuppressed
                          ? Icons.volume_down
                          : Icons.volume_up,
                      size: 14,
                      color: widget.firearmProfile.isSuppressed
                          ? Colors.blueAccent
                          : Colors.orangeAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.firearmProfile.displayName} (${widget.firearmProfile.typicalDbRange})',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.firearmProfile.isSuppressed
                            ? Colors.blueAccent
                            : Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ),
              if (_latestClassification != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_latestClassification!.peakDbFs.toStringAsFixed(1)} dBFS',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),
        TimerDisplay(
          elapsed: sessionState.elapsed,
          label: 'Elapsed Time',
        ),
        const SizedBox(height: 12),
        Text(
          '${sessionState.shots.length}',
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        const Text(
          'Shots Detected',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        const SizedBox(height: 12),

        // Mic and AI Status Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MicIndicator(
              isActive: _phase == SessionPhase.active,
              label: widget.isSimulation ? 'Simulating' : 'Listening',
            ),
            if (_latestClassification != null) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _latestClassification!.isGunshot
                      ? Colors.redAccent.withValues(alpha: 0.3)
                      : Colors.white12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'AI: ${_latestClassification!.label.name} (${(_latestClassification!.confidence * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 11,
                    color: _latestClassification!.isGunshot
                        ? Colors.redAccent
                        : Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),
        const Divider(color: Colors.white24),

        // Shot List
        Expanded(
          child: sessionState.shots.isEmpty
              ? const Center(
                  child: Text(
                    'Listening for gunshots...',
                    style: TextStyle(color: Colors.white38, fontSize: 15),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessionState.shots.length,
                  itemBuilder: (context, index) {
                    final reversedIndex =
                        sessionState.shots.length - 1 - index;
                    final shot = sessionState.shots[reversedIndex];
                    final prevShot = reversedIndex > 0
                        ? sessionState.shots[reversedIndex - 1]
                        : null;

                    Duration? interval;
                    if (prevShot != null) {
                      interval = shot.elapsedTime - prevShot.elapsedTime;
                    } else {
                      interval = shot.elapsedTime;
                    }

                    return ShotListTile(
                      shot: shot,
                      interval: interval,
                    );
                  },
                ),
        ),

        // STOP Button
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: _stopSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 80),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'STOP',
              style: TextStyle(fontSize: 32, letterSpacing: 4),
            ),
          ),
        ),
      ],
    );
  }
}
