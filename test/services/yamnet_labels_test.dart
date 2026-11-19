import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/services/classifier/audio_classification.dart';
import 'package:shot_timer_ai/services/classifier/yamnet_labels.dart';

/// Class names from the bundled class map, by index.
List<String> _classNames() {
  final List<String> lines =
      File('assets/models/yamnet_class_map.csv').readAsLinesSync();
  return [
    for (final String line in lines.skip(1).where((l) => l.trim().isNotEmpty))
      // index,mid,display_name (the name may be quoted and contain commas)
      line.split(',').skip(2).join(',').replaceAll('"', ''),
  ];
}

List<double> _scores(Map<int, double> values) {
  final List<double> s = List<double>.filled(Yamnet.classCount, 0);
  values.forEach((i, v) => s[i] = v);
  return s;
}

AudioClassification _classify(Map<int, double> values) =>
    classificationFromYamnetScores(_scores(values), timestamp: DateTime(2026));

void main() {
  group('class groups match the bundled class map', () {
    final List<String> names = _classNames();

    test('map has one name per model output', () {
      expect(names, hasLength(Yamnet.classCount));
    });

    test('gunshot group is the gunfire family', () {
      expect([for (final i in Yamnet.gunshot) names[i]], [
        'Explosion',
        'Gunshot, gunfire',
        'Machine gun',
        'Fusillade',
        'Artillery fire',
        'Cap gun',
      ]);
    });

    test('other groups point at the intended classes', () {
      expect(names[Yamnet.voice.first], 'Speech');
      expect(names[475], 'Beep, bleep');
      expect(Yamnet.beep, contains(475));
      expect(names[56], 'Hands');
      expect(names[461], 'Slap, smack');
      expect(Yamnet.otherLoud, containsAll([56, 58, 461]));
      expect(names[494], 'Silence');
      expect(Yamnet.background, contains(494));
    });

    test('no class is in two groups', () {
      final List<int> all = [
        ...Yamnet.gunshot,
        ...Yamnet.voice,
        ...Yamnet.beep,
        ...Yamnet.otherLoud,
        ...Yamnet.background,
      ];
      expect(all.toSet(), hasLength(all.length));
    });
  });

  group('classificationFromYamnetScores', () {
    test('a real shot that also scores as a slap is still a gunshot', () {
      // Measured on a public-domain gunshot recording: Slap 0.74, Hands
      // 0.59, Explosion 0.41, Gunshot 0.33.
      final AudioClassification c =
          _classify({461: 0.74, 56: 0.59, 420: 0.41, 421: 0.33});
      expect(c.label, AudioLabel.gunshot);
      expect(c.confidence, closeTo(0.41, 1e-9));
      expect(c.scores[AudioLabel.otherLoudSound], closeTo(0.74, 1e-9));
    });

    test('speech is voice, even with a small gunshot score', () {
      final AudioClassification c = _classify({0: 0.99, 421: 0.05});
      expect(c.label, AudioLabel.voice);
      expect(c.confidence, closeTo(0.99, 1e-9));
      expect(c.isGunshot, isFalse);
    });

    test('a beep stronger than the gunshot score is a beep', () {
      expect(_classify({475: 0.5, 425: 0.2}).label, AudioLabel.beep);
    });

    test('silence is background with zero gunshot score', () {
      final AudioClassification c = _classify({494: 0.8});
      expect(c.label, AudioLabel.backgroundNoise);
      expect(c.gunshotScore, 0);
    });

    test('a clap with no gunshot score is another loud sound', () {
      expect(_classify({58: 0.7}).label, AudioLabel.otherLoudSound);
    });

    test('all-zero scores are background, never gunshot', () {
      expect(_classify({}).label, AudioLabel.backgroundNoise);
    });

    test('carries the given timestamp and levels', () {
      final AudioClassification c = classificationFromYamnetScores(
        _scores({421: 0.5}),
        timestamp: DateTime(2026, 1, 2),
        peakDbFs: -3,
        estimatedDbSpl: 150,
      );
      expect(c.timestamp, DateTime(2026, 1, 2));
      expect(c.peakDbFs, -3);
      expect(c.estimatedDbSpl, 150);
      expect(c.analyzed, isTrue);
    });
  });
}
