import 'dart:async';

/// High-resolution session timer.
///
/// Uses [Stopwatch] for precise elapsed-time measurement and
/// emits periodic ticks for UI display updates.
///
/// The timer does NOT directly modify UI state — it exposes
/// a stream and elapsed getters that providers can observe.
class SessionTimer {
  /// Creates a [SessionTimer].
  ///
  /// [tickIntervalMs] controls how frequently the timer emits
  /// updates. Default is 10ms for centisecond precision.
  SessionTimer({this.tickIntervalMs = 10});

  /// Interval between tick emissions in milliseconds.
  final int tickIntervalMs;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickTimer;
  final StreamController<Duration> _tickController =
      StreamController<Duration>.broadcast();

  /// Stream of elapsed [Duration] values emitted at each tick.
  Stream<Duration> get tickStream => _tickController.stream;

  /// Current elapsed time since the timer was started.
  Duration get elapsed => _stopwatch.elapsed;

  /// Whether the timer is currently running.
  bool get isRunning => _stopwatch.isRunning;

  /// Starts the timer and begins emitting ticks.
  ///
  /// If the timer was already started, this is a no-op.
  void start() {
    if (_stopwatch.isRunning) return;

    _stopwatch.start();
    _tickTimer = Timer.periodic(
      Duration(milliseconds: tickIntervalMs),
      (_) {
        if (!_tickController.isClosed) {
          _tickController.add(_stopwatch.elapsed);
        }
      },
    );
  }

  /// Stops the timer and ceases tick emissions.
  ///
  /// The elapsed time is preserved and can be read via [elapsed].
  void stop() {
    _stopwatch.stop();
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  /// Resets the timer to zero.
  ///
  /// The timer must be stopped before resetting.
  void reset() {
    stop();
    _stopwatch.reset();
  }

  /// Releases timer resources.
  void dispose() {
    stop();
    _tickController.close();
  }
}

