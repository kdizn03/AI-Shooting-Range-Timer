import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/audio/level_analysis.dart';

/// Little-endian PCM16 buffer where every sample is [value].
Uint8List _pcm(int value, {int samples = 4000}) {
  final ByteData d = ByteData(samples * 2);
  for (int i = 0; i < samples; i++) {
    d.setInt16(i * 2, value, Endian.little);
  }
  return d.buffer.asUint8List();
}

void main() {
  group('dbFsFromPeakRatio', () {
    test('full scale is 0 dBFS and half scale is about -6.02 dBFS', () {
      expect(dbFsFromPeakRatio(1), closeTo(0, 1e-9));
      expect(dbFsFromPeakRatio(0.5), closeTo(-6.0206, 1e-3));
    });

    test('zero, negative and NaN never produce -infinity or NaN', () {
      expect(dbFsFromPeakRatio(0), kSilenceFloorDbFs);
      expect(dbFsFromPeakRatio(-1), kSilenceFloorDbFs);
      expect(dbFsFromPeakRatio(double.nan), kSilenceFloorDbFs);
      expect(dbFsFromPeakRatio(1e-12), kSilenceFloorDbFs);
    });
  });

  group('peakDbFsFromPcm16', () {
    test('silence reads the floor, not negative infinity', () {
      final double db = peakDbFsFromPcm16(_pcm(0));
      expect(db, kSilenceFloorDbFs);
      expect(db.isFinite, isTrue);
    });

    test('half-amplitude constant signal is about -6.02 dBFS', () {
      expect(peakDbFsFromPcm16(_pcm(16384)), closeTo(-6.0206, 1e-3));
    });

    test('uses the largest absolute sample, including negative peaks', () {
      final ByteData d = ByteData(8);
      d.setInt16(0, 100, Endian.little);
      d.setInt16(2, -32768, Endian.little);
      d.setInt16(4, 5, Endian.little);
      d.setInt16(6, 0, Endian.little);
      expect(peakDbFsFromPcm16(d.buffer.asUint8List()), closeTo(0, 1e-9));
    });
  });

  group('percentile', () {
    test('interpolates between sorted values', () {
      final List<double> v = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      expect(percentile(v, 0), 1);
      expect(percentile(v, 1), 10);
      expect(percentile(v, 0.5), closeTo(5.5, 1e-9));
    });

    test('empty input and non-finite values are handled', () {
      expect(percentile(const <double>[], 0.5), isNull);
      expect(percentile([double.nan, double.infinity], 0.5), isNull);
      expect(percentile([double.nan, -40.0], 0.5), -40.0);
    });
  });

  group('analyzeCalibration', () {
    test('too few windows is a no-input failure', () {
      final CalibrationOutcome o = analyzeCalibration(List.filled(3, -40));
      expect(o.issue, CalibrationIssue.noInput);
      expect(o.hasSuggestion, isFalse);
    });

    test('digital silence is a no-signal failure with no suggestion', () {
      final CalibrationOutcome o =
          analyzeCalibration(List.filled(20, kSilenceFloorDbFs));
      expect(o.issue, CalibrationIssue.noSignal);
      expect(o.suggestedDbFs, isNull);
    });

    test('suggestion sits 10 dB above the 95th-percentile ambient level', () {
      final CalibrationOutcome o = analyzeCalibration(List.filled(20, -40));
      expect(o.issue, isNull);
      expect(o.suggestedDbFs, -30.0);
      expect(o.warning, isNull);
    });

    test('suggestion is rounded to 0.1 dB', () {
      final List<double> v = List.filled(20, -33.27);
      expect(analyzeCalibration(v).suggestedDbFs, -23.3);
    });

    test('suggestion is clamped to the allowed range', () {
      expect(analyzeCalibration(List.filled(20, -80)).suggestedDbFs, -60);
    });

    test('loud surroundings produce a warning and the top of the range', () {
      final CalibrationOutcome o = analyzeCalibration(List.filled(20, -5));
      expect(o.suggestedDbFs, -1);
      expect(o.warning, contains('very loud'));
    });
  });
}
