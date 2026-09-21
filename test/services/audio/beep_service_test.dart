import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/audio/beep_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (MethodCall methodCall) async {
        return 1;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (MethodCall methodCall) async {
        return 1;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      null,
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      null,
    );
  });

  group('BeepService', () {
    test('can be instantiated, play beep, and dispose cleanly', () async {
      final beepService = BeepService();
      expect(beepService, isNotNull);

      // Verify playBeep executes
      await expectLater(beepService.playBeep(), completes);

      // Verify clean disposal
      await expectLater(beepService.dispose(), completes);
    });
  });
}

