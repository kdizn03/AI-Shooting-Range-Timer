/// Delay options before the starting beep sounds.
enum StartDelayMode {
  /// Beeps immediately upon pressing start.
  instant(0, 'Instant (0s)'),

  /// Beeps after a fixed 3-second standby delay.
  fixed3s(3, 'Fixed (3s)'),

  /// Beeps randomly between 2 and 4 seconds (IPSC/USPSA standard).
  random2to4s(-1, 'Random (2–4s)');

  const StartDelayMode(this.seconds, this.label);

  /// Fixed delay in seconds, or -1 for a randomised delay.
  final int seconds;

  /// Human-readable label.
  final String label;
}
