import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service responsible for playing the audible starting beep buzzer
/// when the start delay ends, signaling the shooter to begin.
class BeepService {
  /// Creates a [BeepService].
  BeepService({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _init();
  }

  final AudioPlayer _player;

  void _init() {
    try {
      // Configure player for low-latency sound effects
      _player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientExclusive,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
              AVAudioSessionOptions.duckOthers,
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notice: AudioContext initialization: $e');
    }
  }

  /// Plays the starting buzzer beep (`assets/sounds/beep.wav`) and
  /// triggers haptic feedback.
  Future<void> playBeep() async {
    try {
      // Trigger haptic feedback for mobile devices
      unawaited(HapticFeedback.heavyImpact());

      // Reset position and play the buzzer asset
      await _player.stop();
      await _player.play(
        AssetSource('sounds/beep.wav'),
        volume: 1.0,
        mode: PlayerMode.lowLatency,
      );
    } catch (e) {
      debugPrint('Error playing starting beep: $e');
    }
  }

  /// Releases audio player resources.
  Future<void> dispose() async {
    try {
      await _player.stop();
      await _player.dispose();
    } catch (e) {
      debugPrint('Error disposing BeepService: $e');
    }
  }
}

