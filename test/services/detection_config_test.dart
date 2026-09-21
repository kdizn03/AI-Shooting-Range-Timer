import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/detection/detection_config.dart';

void main() {
  group('DetectionConfig', () {
    test('default values', () {
      const config = DetectionConfig();
      expect(config.confidenceThreshold, 0.7);
      expect(config.debounceDurationMs, 300);
      expect(config.maxShotsPerSession, 999);
      expect(config.inferenceLatencyCompensationMs, 50);
    });

    test('custom values', () {
      const config = DetectionConfig(
        confidenceThreshold: 0.8,
        debounceDurationMs: 400,
        maxShotsPerSession: 100,
        inferenceLatencyCompensationMs: 60,
      );
      expect(config.confidenceThreshold, 0.8);
      expect(config.debounceDurationMs, 400);
      expect(config.maxShotsPerSession, 100);
      expect(config.inferenceLatencyCompensationMs, 60);
    });
    
    test('debounceDuration computed property', () {
      const config = DetectionConfig(debounceDurationMs: 500);
      expect(config.debounceDuration, const Duration(milliseconds: 500));
    });

    test('latencyCompensation computed property', () {
      const config = DetectionConfig(inferenceLatencyCompensationMs: 75);
      expect(config.latencyCompensation, const Duration(milliseconds: 75));
    });

    test('Equatable equality', () {
      const config1 = DetectionConfig(confidenceThreshold: 0.8);
      const config2 = DetectionConfig(confidenceThreshold: 0.8);
      const config3 = DetectionConfig(confidenceThreshold: 0.9);
      
      expect(config1, config2);
      expect(config1, isNot(config3));
    });
  });
}
