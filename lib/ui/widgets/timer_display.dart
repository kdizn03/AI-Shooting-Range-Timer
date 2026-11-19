import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/utils/timestamp_utils.dart';
import '../theme/tokens.dart';

/// Static `MM:SS.cc` readout.
class TimerDisplay extends StatelessWidget {
  final Duration elapsed;
  final String? label;

  /// Colour of the digits.
  final Color color;

  /// Maximum font size; the readout scales down to fit narrower space.
  final double fontSize;

  const TimerDisplay({
    super.key,
    required this.elapsed,
    this.label,
    this.color = AppColors.textPrimary,
    this.fontSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    final String text = TimestampUtils.formatElapsed(elapsed);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(label!.toUpperCase(), style: AppType.overline),
        // FittedBox scales the dominant timer to the available width so it
        // never overflows on narrow phones or landscape layouts.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            semanticsLabel: 'Elapsed $text',
            style: AppType.timer.copyWith(color: color, fontSize: fontSize),
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}

/// Timer readout bound to a [ValueListenable].
///
/// Only this widget rebuilds on each tick, and it is isolated in a
/// [RepaintBoundary], so the rest of the session screen is untouched by
/// 60 Hz timer updates.
class LiveTimerDisplay extends StatelessWidget {
  /// Creates a [LiveTimerDisplay].
  const LiveTimerDisplay({
    super.key,
    required this.elapsed,
    this.label,
    this.color = AppColors.textPrimary,
    this.fontSize = 96,
  });

  final ValueListenable<Duration> elapsed;
  final String? label;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<Duration>(
        valueListenable: elapsed,
        builder: (context, value, _) =>
            TimerDisplay(
                elapsed: value, label: label, color: color, fontSize: fontSize),
      ),
    );
  }
}
