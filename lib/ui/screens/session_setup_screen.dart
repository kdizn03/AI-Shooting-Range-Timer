import 'package:flutter/material.dart';

import '../../models/firearm_profile.dart';
import 'active_session_screen.dart';

/// Delay options before the starting beep sounds.
enum StartDelayMode {
  /// Beeps immediately upon entering the session.
  instant(0, 'Instant (0s)'),

  /// Beeps after a fixed 3-second standby delay.
  fixed3s(3, 'Fixed (3s)'),

  /// Beeps randomly between 2 and 4 seconds (IPSC/USPSA standard).
  random2to4s(-1, 'Random (2–4s)');

  const StartDelayMode(this.seconds, this.label);
  final int seconds;
  final String label;
}

/// Pre-session configuration screen.
///
/// Allows the shooter to configure:
/// - Firearm profile & decibel threshold (Glock 19 Unsuppressed 155–167 dB, Suppressed 134–140 dB, etc.)
/// - Detection sensitivity (confidence threshold)
/// - Start delay mode (instant, fixed, or random standby delay)
/// - Detection source (Live microphone AI vs. simulated shots)
class SessionSetupScreen extends StatefulWidget {
  /// Creates a [SessionSetupScreen].
  const SessionSetupScreen({super.key});

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  double _sensitivity = 0.7; // default confidence threshold
  StartDelayMode _delayMode = StartDelayMode.fixed3s;
  bool _isSimulation = false;
  FirearmProfile _selectedProfile = FirearmProfile.glock19Unsuppressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Firearm & Decibel Profile section
            const Text(
              'Firearm & Decibel Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select firearm type to set acoustic sound pressure level (dB SPL) and gate thresholds.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<FirearmProfile>(
                      initialValue: _selectedProfile,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Firearm Preset',
                        prefixIcon:
                            Icon(Icons.security, color: Colors.greenAccent),
                        border: OutlineInputBorder(),
                      ),
                      items: FirearmProfile.allPresets.map((profile) {
                        return DropdownMenuItem<FirearmProfile>(
                          value: profile,
                          child: Text(
                            '${profile.displayName} (${profile.typicalDbRange})',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (FirearmProfile? newProfile) {
                        if (newProfile != null) {
                          setState(() {
                            _selectedProfile = newProfile;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _selectedProfile.isSuppressed
                                ? Colors.blueAccent.withValues(alpha: 0.2)
                                : Colors.orangeAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _selectedProfile.isSuppressed
                                ? 'SUPPRESSED'
                                : 'UNSUPPRESSED',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _selectedProfile.isSuppressed
                                  ? Colors.blueAccent
                                  : Colors.orangeAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Nominal: ${_selectedProfile.nominalPeakDbSpl.toStringAsFixed(0)} dB SPL',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70),
                        ),
                        const Spacer(),
                        Text(
                          'Gate: ${_selectedProfile.minPeakDbFs.toStringAsFixed(0)} dBFS',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.greenAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedProfile.description,
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // Sensitivity section
            const Text(
              'Detection Sensitivity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Adjust the AI confidence threshold for gunshot detection. '
              'Higher sensitivity detects quieter shots but may increase false positives.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _sensitivity,
              min: 0.3,
              max: 0.95,
              divisions: 13,
              label: '${(_sensitivity * 100).toInt()}%',
              activeColor: Colors.greenAccent,
              onChanged: (value) {
                setState(() {
                  _sensitivity = value;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('More Sensitive (30%)',
                    style: TextStyle(fontSize: 12, color: Colors.white54)),
                Text('${(_sensitivity * 100).toInt()}%',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.greenAccent)),
                const Text('Stricter (95%)',
                    style: TextStyle(fontSize: 12, color: Colors.white54)),
              ],
            ),
            const SizedBox(height: 28),

            // Start Delay section
            const Text(
              'Start Delay',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Delay before the starting beep sounds and the timer begins.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SegmentedButton<StartDelayMode>(
              segments: StartDelayMode.values
                  .map((mode) => ButtonSegment<StartDelayMode>(
                        value: mode,
                        label: Text(mode.label,
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
              selected: {_delayMode},
              onSelectionChanged: (Set<StartDelayMode> newSelection) {
                setState(() {
                  _delayMode = newSelection.first;
                });
              },
            ),
            const SizedBox(height: 28),

            // Mode section
            const Text(
              'Audio Detection Mode',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: SwitchListTile(
                title: Text(
                  _isSimulation ? 'Simulation Mode' : 'Live Microphone (AI)',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _isSimulation
                      ? 'Simulates shots every 1–3s for dry-fire or testing without live gunfire.'
                      : 'Uses on-device AI to detect real gunshot sounds via the microphone.',
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                secondary: Icon(
                  _isSimulation ? Icons.play_circle_outline : Icons.mic,
                  color:
                      _isSimulation ? Colors.orangeAccent : Colors.greenAccent,
                ),
                value: _isSimulation,
                onChanged: (bool value) {
                  setState(() {
                    _isSimulation = value;
                  });
                },
              ),
            ),
            const SizedBox(height: 36),

            // Begin Button
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (context) => ActiveSessionScreen(
                      sensitivity: _sensitivity,
                      delayMode: _delayMode,
                      isSimulation: _isSimulation,
                      firearmProfile: _selectedProfile,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 64),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('BEGIN',
                  style: TextStyle(fontSize: 22, letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }
}
