import 'package:flutter_test/flutter_test.dart';
import 'package:shot_timer_ai/models/app_settings.dart';
import 'package:shot_timer_ai/models/firearm_profile.dart';
import 'package:shot_timer_ai/models/history_summary.dart';
import 'package:shot_timer_ai/models/session.dart';
import 'package:shot_timer_ai/models/session_statistics.dart';
import 'package:shot_timer_ai/models/shot_event.dart';
import 'package:shot_timer_ai/models/start_delay_mode.dart';

final DateTime _t0 = DateTime(2026, 3, 1, 9);

ShotEvent _shot(int n, int ms,
        {ReviewStatus review = ReviewStatus.unreviewed, double conf = 0.9}) =>
    ShotEvent(
      shotNumber: n,
      elapsedTime: Duration(milliseconds: ms),
      confidence: conf,
      detectionTimestamp: _t0,
      reviewStatus: review,
    );

void main() {
  group('Backward-compatible serialization', () {
    test('ShotEvent without reviewStatus loads as unreviewed', () {
      final ShotEvent e = ShotEvent.fromMap({
        'shotNumber': 1,
        'elapsedTimeMs': 1200,
        'confidence': 0.8,
        'detectionTimestamp': _t0.toIso8601String(),
      });
      expect(e.reviewStatus, ReviewStatus.unreviewed);
    });

    test('ShotEvent review status round-trips', () {
      final ShotEvent e = _shot(1, 1000, review: ReviewStatus.rejected);
      expect(ShotEvent.fromMap(e.toMap()), e);
    });

    test('v1.0 Session map (no pause/simulation fields) still loads', () {
      final Session s = Session.fromMap({
        'id': 'legacy',
        'startTime': _t0.toIso8601String(),
        'endTime': _t0.add(const Duration(seconds: 30)).toIso8601String(),
        'shots': <dynamic>[],
        'status': 'completed',
      });
      expect(s.pausedDuration, Duration.zero);
      expect(s.isSimulated, isFalse);
      expect(s.confidenceThreshold, isNull);
      expect(s.activeDuration, const Duration(seconds: 30));
    });

    test('new Session fields round-trip', () {
      final Session s = Session(
        id: 'x',
        startTime: _t0,
        endTime: _t0.add(const Duration(seconds: 20)),
        status: SessionStatus.completed,
        pausedDuration: const Duration(seconds: 5),
        isSimulated: true,
        confidenceThreshold: 0.65,
        shots: [_shot(1, 1000)],
      );
      expect(Session.fromMap(s.toMap()), s);
    });
  });

  group('SessionStatistics with review and pauses', () {
    test('rejected events are excluded from all metrics', () {
      final Session s = Session(
        id: 's',
        startTime: _t0,
        endTime: _t0.add(const Duration(seconds: 10)),
        shots: [
          _shot(1, 1000, review: ReviewStatus.confirmed, conf: 0.8),
          _shot(2, 1500, review: ReviewStatus.rejected, conf: 0.71),
          _shot(3, 3000, conf: 1.0),
        ],
      );
      final SessionStatistics st = SessionStatistics.fromSession(s);
      expect(st.totalShots, 2);
      expect(st.rejectedShots, 1);
      expect(st.confirmedShots, 1);
      expect(st.intervals, [const Duration(milliseconds: 2000)]);
      expect(st.averageConfidence, closeTo(0.9, 1e-9));
    });

    test('session duration excludes paused time', () {
      final Session s = Session(
        id: 's',
        startTime: _t0,
        endTime: _t0.add(const Duration(seconds: 60)),
        pausedDuration: const Duration(seconds: 15),
      );
      expect(SessionStatistics.fromSession(s).sessionDuration,
          const Duration(seconds: 45));
    });
  });

  group('AppSettings', () {
    test('round-trips through a map', () {
      const AppSettings s = AppSettings(
        useSimulation: true,
        confidenceThreshold: 0.55,
        firearmPreset: FirearmPreset.custom,
        customGateDbFs: -20,
        debounceMs: 250,
        latencyCompensationMs: 30,
        startDelay: StartDelayMode.random2to4s,
        playStartBeep: false,
        hapticOnDetection: false,
      );
      expect(AppSettings.fromMap(s.toMap()), s);
    });

    test('invalid or missing values fall back to safe defaults', () {
      final AppSettings s = AppSettings.fromMap({
        'confidenceThreshold': 5,
        'debounceMs': 'oops',
        'firearmPreset': 'unknown',
      });
      expect(s.confidenceThreshold, 0.95);
      expect(s.debounceMs, const AppSettings().debounceMs);
      expect(s.firearmPreset, const AppSettings().firearmPreset);
    });

    test('custom profile uses the configured gate', () {
      const AppSettings s =
          AppSettings(firearmPreset: FirearmPreset.custom, customGateDbFs: -22);
      expect(s.firearmProfile.minPeakDbFs, -22);
      expect(s.resolveProfile(FirearmPreset.rimfire22).minPeakDbFs,
          FirearmProfile.rimfire22.minPeakDbFs);
    });
  });

  group('HistorySummary', () {
    Session session(String id, int dayOffset, List<int> ms,
            {bool simulated = false}) =>
        Session(
          id: id,
          startTime: _t0.add(Duration(days: dayOffset)),
          endTime: _t0.add(Duration(days: dayOffset, seconds: 20)),
          status: SessionStatus.completed,
          isSimulated: simulated,
          shots: [for (int i = 0; i < ms.length; i++) _shot(i + 1, ms[i])],
        );

    test('excludes simulated sessions by default', () {
      final HistorySummary h = HistorySummary.from([
        session('a', 0, [1000, 2000]),
        session('b', 1, [500, 700, 900], simulated: true),
      ]);
      expect(h.sessionCount, 1);
      expect(h.totalDetections, 2);
      expect(h.simulatedCount, 1);
      expect(h.bestSplit, const Duration(seconds: 1));
    });

    test('aggregates splits across sessions and respects since', () {
      final List<Session> all = [
        session('a', 0, [1000, 2000]), // split 1000
        session('b', 2, [1000, 1500, 2500]), // splits 500, 1000
      ];
      final HistorySummary h = HistorySummary.from(all);
      expect(h.averageSplit, const Duration(milliseconds: 833));
      expect(h.bestSplit, const Duration(milliseconds: 500));
      expect(h.averageDuration, const Duration(seconds: 20));

      final HistorySummary recent =
          HistorySummary.from(all, since: _t0.add(const Duration(days: 1)));
      expect(recent.sessionCount, 1);
    });

    test('sessionsPerBucket keeps empty days for a continuous axis', () {
      final HistorySummary h = HistorySummary.from([
        session('a', 0, [1000]),
        session('b', 2, [1000]),
        session('c', 2, [1000]),
      ]);
      final buckets = h.sessionsPerBucket(
          start: _t0, end: _t0.add(const Duration(days: 2)));
      expect(buckets.map((e) => e.value).toList(), [1, 0, 2]);
    });
  });
}
