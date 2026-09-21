import 'package:flutter/material.dart';
import '../../core/utils/timestamp_utils.dart';

class TimerDisplay extends StatelessWidget {
  final Duration elapsed;
  final String? label;

  const TimerDisplay({
    super.key,
    required this.elapsed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        Text(
          TimestampUtils.formatElapsed(elapsed),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontFamily: 'monospace',
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
