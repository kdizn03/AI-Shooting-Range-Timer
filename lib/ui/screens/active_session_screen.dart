import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/errors/failures.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/timestamp_utils.dart';
import '../../models/detection_engine.dart';
import '../../models/detection_zone.dart';
import '../../models/firearm_profile.dart';
import '../../models/microphone.dart';
import '../../models/session.dart';
import '../../models/shot_event.dart';
import '../../models/start_delay_mode.dart';
import '../../providers/audio_input_provider.dart';
import '../../providers/session_history_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/audio/audio_pipeline.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/beep_service.dart';
import '../../services/audio/mel_spectrogram_preprocessor.dart';
import '../../services/audio/microphone_manager.dart';
import '../../services/classifier/audio_classification.dart';
import '../../services/classifier/classifier_factory.dart';
import '../../services/detection/detection_config.dart';
import '../../services/detection/shot_detector.dart';
import '../theme/tokens.dart';
import '../widgets/audio_status.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/panel.dart';
import '../widgets/readiness.dart';
import '../widgets/shot_list_tile.dart';
import '../widgets/state_views.dart';
import '../widgets/status_tag.dart';
import '../widgets/timer_display.dart';
import 'results_screen.dart';

/// Active shooting session phases.
enum SessionPhase {
  /// Armed and waiting for the shooter to press Start.
  ready,

  /// Shooter is waiting for the starting buzzer (Standby).
  standby,

  /// Starting beep is sounding.
  beep,

  /// Timer is running (or paused) and listening for shots.
  active,

  /// Session has finished and is being saved.
  finished,
}

/// The active session screen.
///
/// Flow: Ready → (Start) → Standby delay → Beep → Running ⇄ Paused → End.
///
/// Performance: the stopwatch is read by a vsync [Ticker] into a
/// [ValueNotifier] consumed only by the timer readout, and classifications
/// (≈4 Hz) feed a separate notifier consumed only by the level meter. The
/// rest of the screen rebuilds only on real state changes (phase, pause,
/// new detection, monitor status). Audio processing is untouched.
///
/// Honesty: events come only from the [ShotDetector] stream (live) or the
/// explicitly chosen simulation mode. If the live pipeline fails, the
/// screen reports the error — it never substitutes simulated events.
class ActiveSessionScreen extends ConsumerStatefulWidget {
  /// Creates an [ActiveSessionScreen].
  const ActiveSessionScreen({
    super.key,
    this.sensitivity = 0.7,
    this.detectionEngine = DetectionEngine.energy,
    this.detectionZone = DetectionZone.standard,
    this.noiseSeedDbFs,
    this.delayMode = StartDelayMode.fixed3s,
    this.isSimulation = false,
    this.firearmProfile = FirearmProfile.glock19Unsuppressed,
    this.debounceMs = DetectionConstants.defaultDebounceDurationMs,
    this.latencyCompensationMs = TimingConstants.estimatedInferenceLatencyMs,
    this.playStartBeep = true,
    this.hapticOnDetection = true,
  });

  /// Detection threshold (0.0–1.0), on [detectionEngine]'s scale.
  final double sensitivity;

  /// Classifier that decides whether a loud sound is a gunshot.
  final DetectionEngine detectionEngine;

  /// Extra filtering profile (Settings → Detection zone).
  final DetectionZone detectionZone;

  /// Saved noise floor for the selected microphone, used until the live
  /// background estimate has enough audio.
  final double? noiseSeedDbFs;

  /// Start delay before the beep sounds.
  final StartDelayMode delayMode;

  /// Whether to simulate shots instead of using the live microphone.
  final bool isSimulation;

  /// Configured firearm acoustic profile (e.g. Glock 19 Unsuppressed vs Suppressed).
  final FirearmProfile firearmProfile;

  /// Detection lockout between events.
  final int debounceMs;

  /// Inference latency subtracted from timestamps.
  final int latencyCompensationMs;

  /// Play the audible start beep.
  final bool playStartBeep;

  /// Vibrate on each detection.
  final bool hapticOnDetection;

  @override
  ConsumerState<ActiveSessionScreen> createState() =>
      _ActiveSessionScreenState();
}

class _ActiveSessionScreenState extends ConsumerState<ActiveSessionScreen>
    with SingleTickerProviderStateMixin {
  late final Stopwatch _stopwatch;
  late final Ticker _ticker;
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<AudioClassification?> _classification =
      ValueNotifier(null);

  /// Latest classifier verdict, kept while level-only readings stream in.
  final ValueNotifier<AudioClassification?> _verdict = ValueNotifier(null);

  SessionPhase _phase = SessionPhase.ready;
  int _countdownSeconds = 0;
  MonitorState _monitor = MonitorState.idle;
  String? _monitorDetail;
  String? _engineLabel;
  DateTime? _lastAudioAt;
  bool _flash = false;

  Timer? _standbyTimer;
  Timer? _mockShotTimer;
  Timer? _watchdog;
  Timer? _flashTimer;

  // Real audio pipeline components
  AudioPipeline? _audioPipeline;

  /// The input actually being recorded from, once started.
  MicRoute? _route;

  /// Warning about the input (selected one missing, or disconnected).
  String? _routeNotice;
  StreamSubscription<MicPresence>? _presenceSubscription;
  StreamSubscription<ZoneDecision>? _zoneSubscription;

  /// Sounds the Detection Zone filtered out so far.
  int _zoneFiltered = 0;
  ShotDetector? _shotDetector;
  StreamSubscription<ShotEvent>? _shotSubscription;
  StreamSubscription<AudioClassification>? _classificationSubscription;
  StreamSubscription<Object>? _errorSubscription;

  final Random _random = Random();
  final BeepService _beepService = BeepService();
  int _shotCount = 0;

  @override
  void initState() {
    super.initState();
    _stopwatch = Stopwatch();
    _ticker = createTicker((_) => _elapsed.value = _stopwatch.elapsed);
    // Load the classifier while the shooter is getting ready, so the first
    // shots after the beep are not missed while a model loads.
    if (!widget.isSimulation) {
      _classifierLoad = loadAudioClassifier(widget.detectionEngine);
    }
  }

  /// Classifier being loaded for a live session (see [initState]).
  Future<LoadedClassifier>? _classifierLoad;

  /// Whether the pipeline took ownership of the loaded classifier.
  bool _classifierOwned = false;

  @override
  void dispose() {
    _ticker.dispose();
    _standbyTimer?.cancel();
    _mockShotTimer?.cancel();
    _watchdog?.cancel();
    _flashTimer?.cancel();
    _shotSubscription?.cancel();
    _presenceSubscription?.cancel();
    _zoneSubscription?.cancel();
    _classificationSubscription?.cancel();
    _errorSubscription?.cancel();
    _audioPipeline?.dispose();
    if (!_classifierOwned) {
      _classifierLoad?.then((l) => l.classifier.dispose()).ignore();
    }
    _shotDetector?.dispose();
    _beepService.dispose();
    _elapsed.dispose();
    _classification.dispose();
    _verdict.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

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
      setState(() => _countdownSeconds--);
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _triggerBeepAndStart();
      }
    });
  }

  void _cancelStandby() {
    _standbyTimer?.cancel();
    setState(() => _phase = SessionPhase.ready);
  }

  void _triggerBeepAndStart() async {
    if (!mounted) return;

    setState(() => _phase = SessionPhase.beep);

    if (widget.playStartBeep) {
      // Plays the audible buzzer and triggers haptic feedback.
      unawaited(_beepService.playBeep());
    } else {
      unawaited(HapticFeedback.heavyImpact());
    }

    // Brief visual beep duration (300ms)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    _startActiveSession();
  }

  void _startActiveSession() async {
    ref.read(sessionProvider.notifier).startSession(
          firearmProfile: widget.firearmProfile,
          isSimulated: widget.isSimulation,
          confidenceThreshold: widget.sensitivity,
          detectionZone: widget.isSimulation ? null : widget.detectionZone.name,
        );
    _stopwatch.start();
    _ticker.start();

    setState(() {
      _phase = SessionPhase.active;
      _monitor =
          widget.isSimulation ? MonitorState.simulated : MonitorState.starting;
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
        debounceDurationMs: widget.debounceMs,
        inferenceLatencyCompensationMs: widget.latencyCompensationMs,
        detectionZone: widget.detectionZone,
      );

      _shotDetector = ShotDetector(config: config);
      _shotDetector!.start(DateTime.now());

      final AudioService audioService = ref.read(audioServiceFactoryProvider)();
      final preprocessor = MelSpectrogramPreprocessor();
      final LoadedClassifier loaded = await (_classifierLoad ??=
          loadAudioClassifier(widget.detectionEngine));
      if (!mounted) return;
      final classifier = loaded.classifier;
      _classifierOwned = true;

      _audioPipeline = AudioPipeline(
        audioService: audioService,
        audioPreprocessor: preprocessor,
        audioClassifier: classifier,
        shotDetector: _shotDetector!,
        noiseSeedDbFs: widget.noiseSeedDbFs,
      );

      _shotSubscription = _shotDetector!.shotStream.listen(_onDetection);
      _zoneSubscription = _shotDetector!.zoneDecisions.listen((d) {
        if (d.verdict == ZoneVerdict.rejected && mounted) {
          setState(() => _zoneFiltered++);
        }
      });

      _classificationSubscription = _audioPipeline!.classificationStream.listen(
        (AudioClassification classification) {
          if (!mounted) return;
          _lastAudioAt = DateTime.now();
          _classification.value = classification;
          if (classification.analyzed) _verdict.value = classification;
          if (_monitor == MonitorState.starting ||
              _monitor == MonitorState.noSignal) {
            setState(() {
              _monitor = MonitorState.listening;
              _monitorDetail = null;
            });
          }
        },
      );

      _errorSubscription = _audioPipeline!.errorStream.listen((Object e) {
        if (!mounted) return;
        setState(() {
          _monitor = MonitorState.error;
          _monitorDetail = 'Microphone stream error: $e';
        });
      });

      await _audioPipeline!.start();
      if (!mounted) return;
      final MicRoute? route = audioService.route;
      setState(() {
        _engineLabel = loaded.engineLabel;
        _route = route;
        if (route != null && route.selectedMissing) {
          _routeNotice = '${route.selection.displayName} is not connected. '
              'Recording from the system default input instead.';
        }
      });
      if (route != null) {
        ref
            .read(sessionProvider.notifier)
            .setAudioDetails(inputLabel: route.displayName);
        _watchRoute(route);
      }
      _lastAudioAt = DateTime.now();
      _watchdog =
          Timer.periodic(const Duration(seconds: 1), (_) => _checkSignal());
    } on MicrophonePermissionDeniedException {
      if (!mounted) return;
      setState(() {
        _monitor = MonitorState.permissionDenied;
        _monitorDetail =
            'No audio is being captured. Allow microphone access in system '
            'settings, then start a new session.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _monitor = MonitorState.error;
        _monitorDetail = 'Could not start audio monitoring: $e';
      });
    }
  }

  /// Watches the selected external input while recording from it.
  ///
  /// Policy when it disappears: detection and the timer pause, and the
  /// screen says so. The operating system may already be recording from
  /// another input (usually the built-in microphone); resuming continues
  /// with whatever input it routes. Nothing switches silently.
  void _watchRoute(MicRoute route) {
    final MicrophoneManager manager = ref.read(microphoneManagerProvider);
    if (route.device == null) return; // OS default: nothing to lose.
    if (!manager.canMonitorDuringSession) {
      setState(() => _routeNotice ??=
          'Input changes are not monitored during sessions on this platform. '
          'If the microphone is unplugged, the system may switch inputs.');
      return;
    }
    _presenceSubscription =
        manager.watch(route.selection).listen((MicPresence p) {
      if (!mounted || _phase == SessionPhase.finished) return;
      if (p == MicPresence.missing) {
        if (_phase == SessionPhase.active && !_isPaused) _pause();
        setState(() => _routeNotice =
            '${route.displayName} disconnected. Detection is paused. The '
            'system may now be recording from another input (usually the '
            'built-in microphone); Resume continues with that input.');
      } else if (p == MicPresence.connected && _routeNotice != null &&
          _routeNotice!.contains('disconnected')) {
        setState(() => _routeNotice =
            '${route.displayName} is connected again. This session continues '
            'on the input the system chose; start a new session to be sure '
            'it records from ${route.displayName}.');
      }
    });
  }

  bool get _isPaused => ref.read(sessionProvider).isPaused;

  /// Flags a stalled audio stream (no frames for > 2 s).
  void _checkSignal() {
    if (!mounted || _monitor != MonitorState.listening) return;
    final DateTime? last = _lastAudioAt;
    if (last != null &&
        DateTime.now().difference(last) > const Duration(seconds: 2)) {
      setState(() {
        _monitor = MonitorState.noSignal;
        _monitorDetail = 'No audio frames received for over 2 seconds.';
      });
    }
  }

  void _onDetection(ShotEvent shot) {
    if (!mounted) return;
    ref.read(sessionProvider.notifier).addShot(shot);
    if (widget.hapticOnDetection) unawaited(HapticFeedback.mediumImpact());
    _flashTimer?.cancel();
    setState(() => _flash = true);
    _flashTimer = Timer(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _flash = false);
    });
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

      _onDetection(ShotEvent(
        shotNumber: _shotCount,
        elapsedTime: _stopwatch.elapsed,
        confidence: 0.85 + (_random.nextDouble() * 0.14),
        detectionTimestamp: DateTime.now(),
        peakDecibels: simulatedDb,
      ));
      _scheduleMockShot();
    });
  }

  void _pause() {
    if (_phase != SessionPhase.active) return;
    _stopwatch.stop();
    _ticker.stop();
    _elapsed.value = _stopwatch.elapsed;
    _mockShotTimer?.cancel();
    _shotDetector?.pause();
    ref.read(sessionProvider.notifier).pauseSession();
    ref.read(sessionProvider.notifier).updateElapsed(_stopwatch.elapsed);
  }

  void _resume() {
    if (_phase != SessionPhase.active) return;
    _shotDetector?.resume();
    ref.read(sessionProvider.notifier).resumeSession();
    _stopwatch.start();
    _ticker.start();
    if (widget.isSimulation) _scheduleMockShot();
    _lastAudioAt = DateTime.now();
  }

  Future<void> _stopSession() async {
    if (_phase == SessionPhase.finished) return;
    setState(() => _phase = SessionPhase.finished);

    _stopwatch.stop();
    _ticker.stop();
    _standbyTimer?.cancel();
    _mockShotTimer?.cancel();
    _watchdog?.cancel();

    // Stop the pipeline first: it gives sounds still awaiting a verdict
    // one, and their detections must reach _onDetection.
    await _presenceSubscription?.cancel();
    await _audioPipeline?.stop();
    _shotDetector?.stop();
    if (_shotDetector != null) {
      ref.read(sessionProvider.notifier).setAudioDetails(
          zoneFilteredCount: _shotDetector!.zoneRejectedCount);
    }
    // Shot events are delivered asynchronously; let any from the flush
    // arrive before unsubscribing.
    await Future<void>.delayed(Duration.zero);
    await _shotSubscription?.cancel();
    await _classificationSubscription?.cancel();
    await _errorSubscription?.cancel();

    final notifier = ref.read(sessionProvider.notifier);
    notifier.updateElapsed(_stopwatch.elapsed);
    notifier.stopSession();
    final Session? session = ref.read(sessionProvider).session;
    if (session == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    bool saveFailed = false;
    try {
      await ref.read(sessionHistoryControllerProvider).save(session);
    } catch (e) {
      debugPrint('Failed to save session: $e');
      saveFailed = true;
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (context) =>
              ResultsScreen(session: session, saveFailed: saveFailed),
        ),
      );
    }
  }

  Future<void> _confirmEnd() async {
    final bool end = await showConfirmDialog(
      context,
      title: 'End session?',
      message: 'The timer stops and the session is saved with '
          '${ref.read(sessionProvider).shots.length} detected events. '
          'The timer keeps running while this dialog is open.',
      confirmLabel: 'End session',
      cancelLabel: 'Keep running',
      icon: Icons.stop_circle_outlined,
    );
    if (end && mounted) await _stopSession();
  }

  bool get _isRunningPhase =>
      _phase == SessionPhase.active || _phase == SessionPhase.beep;

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final SessionState state = ref.watch(sessionProvider);
    final bool paused = state.isPaused && _phase == SessionPhase.active;
    final MonitorState monitor = paused ? MonitorState.paused : _monitor;

    return PopScope(
      canPop: !_isRunningPhase && _phase != SessionPhase.finished,
      onPopInvokedWithResult: (didPop, dynamic result) {
        if (didPop) return;
        if (_isRunningPhase) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: switch (_phase) {
            SessionPhase.ready => _ReadyView(
                widget: widget,
                onStart: _initiateStandby,
                onCancel: () => Navigator.of(context).maybePop(),
              ),
            SessionPhase.standby => _StandbyView(
                seconds: _countdownSeconds,
                random: widget.delayMode == StartDelayMode.random2to4s,
                onCancel: _cancelStandby,
              ),
            SessionPhase.finished =>
              const LoadingState(label: 'Saving session…'),
            _ => _RunningView(
                widget: widget,
                state: state,
                paused: paused,
                beep: _phase == SessionPhase.beep,
                elapsed: _elapsed,
                classification: _classification,
                verdict: _verdict,
                route: _route,
                routeNotice: _routeNotice,
                zoneFiltered: _zoneFiltered,
                monitor: monitor,
                monitorDetail: paused ? null : _monitorDetail,
                engineLabel: _engineLabel,
                flash: _flash,
                onPause: _pause,
                onResume: _resume,
                onEnd: _confirmEnd,
              ),
          },
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Ready
// -----------------------------------------------------------------------------

class _ReadyView extends ConsumerWidget {
  const _ReadyView({
    required this.widget,
    required this.onStart,
    required this.onCancel,
  });

  final ActiveSessionScreen widget;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Readiness? readiness = ref.watch(readinessProvider);
    final ReadinessItem? mic =
        widget.isSimulation || readiness == null ? null : readiness.items.first;

    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.xs + 2),
          child: Row(
            children: [
              SizedBox(width: 120, child: Text(k, style: AppType.caption)),
              Expanded(child: Text(v, style: AppType.body)),
            ],
          ),
        );

    return Column(
      children: [
        _TopBar(
          leading: IconButton(
            tooltip: 'Back',
            onPressed: onCancel,
            icon: const Icon(Icons.arrow_back),
          ),
          status: const StatusTag(
              label: 'Armed',
              icon: Icons.radio_button_checked,
              tone: Tone.info),
          trailing: widget.isSimulation
              ? const StatusTag(
                  label: 'Simulation',
                  tone: Tone.info,
                  icon: Icons.science_outlined)
              : null,
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpace.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TimerDisplay(
                      elapsed: Duration.zero,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpace.xl),
                    Panel(
                      child: Column(
                        children: [
                          row('Profile', widget.firearmProfile.displayName),
                          row('Decibel gate',
                              '${widget.firearmProfile.minPeakDbFs.toStringAsFixed(0)} dBFS'),
                          row(
                              'Detection',
                              widget.isSimulation
                                  ? 'Simulated events'
                                  : '${widget.detectionEngine.label} · '
                                      '≥ ${Fmt.percent(widget.sensitivity)}'),
                          if (!widget.isSimulation) ...[
                            row('Microphone',
                                ref.watch(micSelectionProvider).displayName),
                            row('Detection zone', widget.detectionZone.label),
                          ],
                          row('Start delay', widget.delayMode.label),
                          row(
                              'Source',
                              widget.isSimulation
                                  ? 'Simulation (no microphone)'
                                  : 'Live microphone'),
                        ],
                      ),
                    ),
                    if (mic != null) ...[
                      const SizedBox(height: AppSpace.md),
                      InlineNotice(
                        icon: mic.icon,
                        color: mic.tone == Tone.neutral
                            ? AppColors.info
                            : mic.tone.color,
                        message: 'Microphone: ${mic.value}',
                      ),
                    ],
                    if (widget.isSimulation) ...[
                      const SizedBox(height: AppSpace.md),
                      const InlineNotice(
                        icon: Icons.science_outlined,
                        message: 'Simulation mode generates random events. '
                            'They are not real detections.',
                      ),
                    ],
                    const SizedBox(height: AppSpace.xl),
                    FilledButton.icon(
                      autofocus: true,
                      onPressed: onStart,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text('START'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(72),
                        textStyle: AppType.button
                            .copyWith(fontSize: 20, letterSpacing: 2),
                      ),
                    ),
                    const SizedBox(height: AppSpace.sm),
                    const Text(
                      'The beep sounds after the start delay. Timing begins on the beep.',
                      textAlign: TextAlign.center,
                      style: AppType.caption,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Standby
// -----------------------------------------------------------------------------

class _StandbyView extends StatelessWidget {
  const _StandbyView({
    required this.seconds,
    required this.random,
    required this.onCancel,
  });

  final int seconds;

  /// Random delays are not counted down, so the beep stays unpredictable.
  final bool random;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StatusTag(
                label: 'STANDBY',
                tone: Tone.warning,
                icon: Icons.hourglass_top),
            const SizedBox(height: AppSpace.xl),
            Semantics(
              liveRegion: true,
              label: random ? 'Wait for the beep' : 'Beep in $seconds seconds',
              excludeSemantics: true,
              child: Text(
                random ? '— —' : '$seconds',
                style: AppType.timer
                    .copyWith(fontSize: 120, color: AppColors.warning),
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Text(random ? 'Wait for the beep' : 'Beep in $seconds s',
                style: AppType.bodySecondary),
            const SizedBox(height: AppSpace.xxl),
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(200, 56)),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Running / paused
// -----------------------------------------------------------------------------

class _RunningView extends StatelessWidget {
  const _RunningView({
    required this.widget,
    required this.state,
    required this.paused,
    required this.beep,
    required this.elapsed,
    required this.classification,
    required this.verdict,
    required this.route,
    required this.routeNotice,
    required this.zoneFiltered,
    required this.monitor,
    required this.monitorDetail,
    required this.engineLabel,
    required this.flash,
    required this.onPause,
    required this.onResume,
    required this.onEnd,
  });

  final ActiveSessionScreen widget;
  final SessionState state;
  final bool paused;
  final bool beep;
  final ValueListenable<Duration> elapsed;
  final ValueListenable<AudioClassification?> classification;
  final ValueListenable<AudioClassification?> verdict;
  final MicRoute? route;
  final String? routeNotice;
  final int zoneFiltered;
  final MonitorState monitor;
  final String? monitorDetail;
  final String? engineLabel;
  final bool flash;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final List<ShotEvent> shots = state.shots;
    final ShotEvent? last = shots.isEmpty ? null : shots.last;
    final Duration? lastSplit = shots.length >= 2
        ? shots.last.elapsedTime - shots[shots.length - 2].elapsedTime
        : null;

    final Widget topBar = _TopBar(
      leading: IconButton(
        tooltip: 'End session',
        onPressed: beep ? null : onEnd,
        icon: const Icon(Icons.close),
      ),
      status: beep
          ? const StatusTag(
              label: 'BEEP', tone: Tone.accent, icon: Icons.campaign)
          : paused
              ? const StatusTag(
                  label: 'PAUSED', tone: Tone.warning, icon: Icons.pause)
              : const StatusTag(
                  label: 'RUNNING',
                  tone: Tone.accent,
                  icon: Icons.fiber_manual_record),
      trailing: widget.isSimulation
          ? const StatusTag(
              label: 'Simulation',
              tone: Tone.info,
              icon: Icons.science_outlined)
          : StatusTag(
              label: widget.firearmProfile.displayName, icon: Icons.tune),
    );

    Widget timerOf(double size) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: LiveTimerDisplay(
            elapsed: elapsed,
            fontSize: size,
            color: paused ? AppColors.warning : AppColors.textPrimary,
          ),
        );

    final Widget metrics = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Metric(
              label: 'Detections',
              value: '${shots.length}',
              accent: true,
              flash: flash,
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: _Metric(
              label: 'Last event',
              value: last == null
                  ? '—'
                  : TimestampUtils.formatElapsed(last.elapsedTime),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: _Metric(
              label: 'Last split',
              value: lastSplit == null ? '—' : Fmt.split(lastSplit),
            ),
          ),
        ],
      ),
    );

    final Widget audio = Panel(
      padding: const EdgeInsets.all(AppSpace.md),
      child: AudioStatus(
        state: monitor,
        classification: classification,
        verdict: verdict,
        gateDbFs: widget.firearmProfile.minPeakDbFs,
        engineLabel: engineLabel,
        detail: monitorDetail,
        hasAudioInput: !widget.isSimulation,
        footer: widget.isSimulation
            ? null
            : _AudioContext(
                route: route,
                zone: widget.detectionZone,
                zoneFiltered: zoneFiltered,
                notice: routeNotice,
              ),
      ),
    );

    Widget controlsOf({required bool narrow}) => Row(
          children: [
            Expanded(
              child: paused
                  ? FilledButton.icon(
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow, size: 26),
                      label: const Text('Resume'),
                      style: FilledButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.controlHeight),
                          textStyle: AppType.button.copyWith(fontSize: 17)),
                    )
                  : OutlinedButton.icon(
                      onPressed: beep ? null : onPause,
                      icon: const Icon(Icons.pause, size: 26),
                      label: const Text('Pause'),
                      style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(AppSizes.controlHeight),
                          textStyle: AppType.button.copyWith(fontSize: 17)),
                    ),
            ),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: FilledButton.icon(
                onPressed: beep ? null : onEnd,
                icon: const Icon(Icons.stop, size: 26),
                label: Text(narrow ? 'End' : 'End session',
                    semanticsLabel: 'End session', maxLines: 1),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size.fromHeight(AppSizes.controlHeight),
                  textStyle: AppType.button.copyWith(fontSize: 17),
                ),
              ),
            ),
          ],
        );

    final Widget timeline = _Timeline(
      shots: shots,
      simulated: widget.isSimulation,
      threshold: widget.sensitivity,
      paused: paused,
    );

    return LayoutBuilder(builder: (context, c) {
      // Side-by-side in landscape (tablets, desktop, phones on their side);
      // portrait devices get a single focused column.
      final bool twoPane = c.maxWidth > c.maxHeight && c.maxWidth >= 560;
      final double gutter = c.maxWidth >= 1024 ? AppSpace.xl : AppSpace.lg;
      final Widget controls = controlsOf(narrow: c.maxWidth < 420);
      final Widget timer = timerOf(twoPane || c.maxWidth >= 600 ? 160 : 96);

      if (twoPane) {
        return Column(
          children: [
            topBar,
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, gutter),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  timer,
                                  metrics,
                                  const SizedBox(height: AppSpace.md),
                                  audio,
                                  const SizedBox(height: AppSpace.md),
                                ],
                              ),
                            ),
                          ),
                          controls,
                        ],
                      ),
                    ),
                    SizedBox(width: gutter),
                    Expanded(flex: c.maxWidth >= 1280 ? 6 : 5, child: timeline),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      return Column(
        children: [
          topBar,
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                timer,
                metrics,
                const SizedBox(height: AppSpace.sm),
                audio,
                const SizedBox(height: AppSpace.sm),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: timeline,
            ),
          ),
          Padding(
            padding:
                EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, AppSpace.md),
            child: controls,
          ),
        ],
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.leading, required this.status, this.trailing});

  final Widget leading;
  final Widget status;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.xs, vertical: AppSpace.xs),
      child: Row(
        children: [
          leading,
          const SizedBox(width: AppSpace.xs),
          status,
          const Spacer(),
          if (trailing != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpace.md),
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.accent = false,
    this.flash = false,
  });

  final String label;
  final String value;
  final bool accent;

  /// Briefly highlight the border when a new event arrives.
  final bool flash;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      liveRegion: accent,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppDurations.respect(context, AppDurations.fast),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.md, vertical: AppSpace.md),
        decoration: BoxDecoration(
          color: flash
              ? AppColors.tint(AppColors.accent, 0.14)
              : AppColors.surface,
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: flash ? AppColors.accent : AppColors.border,
            width: flash ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: AppType.overline.copyWith(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: AppSpace.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: AppType.metric.copyWith(
                  fontSize: accent ? 30 : 20,
                  color: accent ? AppColors.accent : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.shots,
    required this.simulated,
    required this.threshold,
    required this.paused,
  });

  final List<ShotEvent> shots;
  final bool simulated;
  final double threshold;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.md, AppSpace.lg, AppSpace.md),
            child: Row(
              children: [
                const Expanded(
                  child: Text('EVENT TIMELINE', style: AppType.overline),
                ),
                Text('newest first',
                    style: AppType.caption.copyWith(fontSize: 11)),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: shots.isEmpty
                ? EmptyState(
                    compact: true,
                    icon: paused ? Icons.pause : Icons.hearing,
                    title: paused
                        ? 'Paused'
                        : simulated
                            ? 'Waiting for simulated events'
                            : 'Listening for events',
                    message: paused
                        ? 'Detections are ignored until you resume.'
                        : 'Detected events appear here as they happen. They are '
                            'unreviewed until you confirm them in results.',
                  )
                : ListView.builder(
                    itemCount: shots.length,
                    itemBuilder: (context, index) {
                      final int i = shots.length - 1 - index;
                      final ShotEvent shot = shots[i];
                      final Duration interval = i > 0
                          ? shot.elapsedTime - shots[i - 1].elapsedTime
                          : shot.elapsedTime;
                      return DetectionEventItem(
                        key: ValueKey(shot.shotNumber),
                        shot: shot,
                        interval: interval,
                        threshold: threshold,
                        simulated: simulated,
                        isLatest: index == 0,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Input, detection zone and filtering shown under the live audio status.
class _AudioContext extends StatelessWidget {
  const _AudioContext({
    required this.route,
    required this.zone,
    required this.zoneFiltered,
    required this.notice,
  });

  final MicRoute? route;
  final DetectionZone zone;
  final int zoneFiltered;
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final MicRoute? r = route;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.xs,
          children: [
            StatusTag(
              label: r == null ? 'Input: starting…' : r.displayName,
              icon: Icons.mic_none,
              dense: true,
            ),
            if (r?.device != null)
              StatusTag(label: r!.device!.kind.label, dense: true),
            StatusTag(label: zone.label, icon: Icons.radar, dense: true),
            if (zone == DetectionZone.nearField)
              StatusTag(
                label: 'Filtered $zoneFiltered',
                icon: Icons.filter_list,
                tone: zoneFiltered > 0 ? Tone.info : Tone.neutral,
                dense: true,
              ),
          ],
        ),
        if (notice != null) ...[
          const SizedBox(height: AppSpace.sm),
          Text(notice!,
              style: AppType.caption.copyWith(color: AppColors.warning)),
        ],
      ],
    );
  }
}
