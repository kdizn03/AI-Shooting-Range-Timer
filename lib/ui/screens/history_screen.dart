import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/session_history_provider.dart';
import 'results_screen.dart';

/// Displays a list of past shooting sessions.
///
/// Users can tap a session to view its results, or swipe
/// to delete it from history.
class HistoryScreen extends ConsumerWidget {
  /// Creates a [HistoryScreen].
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(sessionHistoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: historyAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text(
                    'No sessions yet',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Complete a session to see it here',
                    style: TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              final dateStr =
                  session.startTime.toString().substring(0, 16);
              return Dismissible(
                key: Key(session.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.redAccent,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  ref
                      .read(sessionRepositoryProvider)
                      .deleteSession(session.id);
                  // ignore: unused_result
                  ref.refresh(sessionHistoryProvider);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.greenAccent.withValues(alpha: 0.2),
                      child: Text(
                        '${session.shotCount}',
                        style:
                            const TextStyle(color: Colors.greenAccent),
                      ),
                    ),
                    title: Text(dateStr),
                    subtitle: Text(
                      '${session.shotCount} shots • '
                      '${session.duration.inSeconds}s',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (context) =>
                              ResultsScreen(session: session),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error: $err')),
      ),
    );
  }
}
