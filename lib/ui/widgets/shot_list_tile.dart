import 'package:flutter/material.dart';

import '../../core/utils/timestamp_utils.dart';
import '../../models/shot_event.dart';

class ShotListTile extends StatelessWidget {
  final ShotEvent shot;
  final Duration? interval;

  const ShotListTile({
    super.key,
    required this.shot,
    this.interval,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${shot.shotNumber}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TimestampUtils.formatElapsed(shot.elapsedTime),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (interval != null)
                    Text(
                      TimestampUtils.formatInterval(interval!),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            // Decibel badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.volume_up, size: 14, color: Colors.orangeAccent),
                  const SizedBox(width: 4),
                  Text(
                    '${shot.peakDecibels.toStringAsFixed(0)} dB',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Confidence badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.analytics, size: 14, color: Colors.greenAccent),
                  const SizedBox(width: 4),
                  Text(
                    '${(shot.confidence * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
