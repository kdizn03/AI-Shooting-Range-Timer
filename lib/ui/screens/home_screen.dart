import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_screen.dart';
import 'session_setup_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shot Timer AI'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.timer,
              size: 100,
              color: Colors.greenAccent,
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => const SessionSetupScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(200, 64),
              ),
              child: const Text('Start Session', style: TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (context) => const HistoryScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(200, 56),
                side: const BorderSide(color: Colors.white54),
              ),
              child: const Text('Session History'),
            ),
            const Spacer(),
            const Text(
              'v1.0.0',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
