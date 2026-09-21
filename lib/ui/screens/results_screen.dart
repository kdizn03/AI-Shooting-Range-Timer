import 'package:flutter/material.dart';

import '../../core/utils/timestamp_utils.dart';
import '../../models/session.dart';
import '../../models/session_statistics.dart';
import '../../models/shot_event.dart';
import '../widgets/shot_list_tile.dart';
import '../widgets/statistics_card.dart';
import 'home_screen.dart';
import 'session_setup_screen.dart';

class ResultsScreen extends StatelessWidget {
  final Session session;

  const ResultsScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final SessionStatistics statistics =
        SessionStatistics.fromSession(session);
    final List<ShotEvent> shots = session.shots;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Results'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Firearm Profile banner
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: session.firearmProfile.isSuppressed
                    ? Colors.blueAccent.withValues(alpha: 0.15)
                    : Colors.orangeAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: session.firearmProfile.isSuppressed
                      ? Colors.blueAccent
                      : Colors.orangeAccent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    session.firearmProfile.isSuppressed
                        ? Icons.volume_down
                        : Icons.volume_up,
                    color: session.firearmProfile.isSuppressed
                        ? Colors.blueAccent
                        : Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.firearmProfile.displayName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        Text(
                          '${session.firearmProfile.typicalDbRange} • ${session.firearmProfile.caliber}',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Top stats row
            Row(
              children: [
                Expanded(
                  child: StatisticsCard(
                    label: 'Total Shots',
                    value: statistics.totalShots.toString(),
                    icon: Icons.numbers,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatisticsCard(
                    label: 'Duration',
                    value: TimestampUtils.formatElapsed(
                        statistics.sessionDuration),
                    icon: Icons.schedule,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Interval stats row
            Row(
              children: [
                Expanded(
                  child: StatisticsCard(
                    label: 'Avg Interval',
                    value: statistics.averageInterval != null
                        ? TimestampUtils.formatSeconds(
                            statistics.averageInterval!)
                        : '-',
                    icon: Icons.timer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatisticsCard(
                    label: 'Fastest',
                    value: statistics.fastestInterval != null
                        ? TimestampUtils.formatSeconds(
                            statistics.fastestInterval!)
                        : '-',
                    icon: Icons.bolt,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatisticsCard(
                    label: 'Slowest',
                    value: statistics.slowestInterval != null
                        ? TimestampUtils.formatSeconds(
                            statistics.slowestInterval!)
                        : '-',
                    icon: Icons.hourglass_bottom,
                  ),
                ),
              ],
            ),

            // Decibel stats row
            if (statistics.avgDecibels != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatisticsCard(
                      label: 'Avg Decibels',
                      value:
                          '${statistics.avgDecibels!.toStringAsFixed(1)} dB',
                      icon: Icons.volume_down,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatisticsCard(
                      label: 'Peak Decibels',
                      value:
                          '${statistics.maxDecibels!.toStringAsFixed(1)} dB',
                      icon: Icons.volume_up,
                    ),
                  ),
                ],
              ),
            ],

            if (statistics.firstShotTime != null) ...[
              const SizedBox(height: 12),
              StatisticsCard(
                label: 'First Shot',
                value:
                    '${TimestampUtils.formatSeconds(statistics.firstShotTime!)}s',
                icon: Icons.first_page,
              ),
            ],
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Shot Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),

            // Shot list
            Expanded(
              child: shots.isEmpty
                  ? const Center(
                      child: Text(
                        'No shots detected',
                        style: TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      itemCount: shots.length,
                      itemBuilder: (context, index) {
                        final shot = shots[index];
                        final prevShot = index > 0 ? shots[index - 1] : null;
                        return ShotListTile(
                          shot: shot,
                          interval: shot.intervalFrom(prevShot),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                            builder: (context) => const HomeScreen()),
                        (route) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save & Close'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute<void>(
                            builder: (context) => const SessionSetupScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('New Session'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
