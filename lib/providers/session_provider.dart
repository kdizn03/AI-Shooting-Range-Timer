import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/firearm_profile.dart';
import '../models/session.dart';
import '../models/shot_event.dart';

/// Live state of the in-progress session.
class SessionState {
  final Session? session;
  final bool isRunning;
  final Duration elapsed;
  final List<ShotEvent> shots;

  /// Whether the running session is currently paused.
  final bool isPaused;

  /// Wall-clock time the current pause began, if paused.
  final DateTime? pausedAt;

  /// Accumulated paused time from completed pauses.
  final Duration pausedDuration;

  SessionState({
    this.session,
    this.isRunning = false,
    this.elapsed = Duration.zero,
    this.shots = const [],
    this.isPaused = false,
    this.pausedAt,
    this.pausedDuration = Duration.zero,
  });

  SessionState copyWith({
    Session? session,
    bool? isRunning,
    Duration? elapsed,
    List<ShotEvent>? shots,
    bool? isPaused,
    DateTime? pausedAt,
    bool clearPausedAt = false,
    Duration? pausedDuration,
  }) {
    return SessionState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      elapsed: elapsed ?? this.elapsed,
      shots: shots ?? this.shots,
      isPaused: isPaused ?? this.isPaused,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedDuration: pausedDuration ?? this.pausedDuration,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState());

  void startSession({
    FirearmProfile firearmProfile = FirearmProfile.glock19Unsuppressed,
    bool isSimulated = false,
    double? confidenceThreshold,
    String? detectionZone,
  }) {
    final session = Session(
      id: const Uuid().v4(),
      startTime: DateTime.now(),
      status: SessionStatus.active,
      firearmProfile: firearmProfile,
      isSimulated: isSimulated,
      confidenceThreshold: confidenceThreshold,
      detectionZone: detectionZone,
    );
    state = SessionState(session: session, isRunning: true);
  }

  /// Records the input actually used and how many sounds the Detection
  /// Zone filtered out.
  void setAudioDetails({String? inputLabel, int? zoneFilteredCount}) {
    final Session? s = state.session;
    if (s == null) return;
    state = state.copyWith(
        session: s.copyWith(
            inputLabel: inputLabel, zoneFilteredCount: zoneFilteredCount));
  }

  /// Pauses the running session. Detections are not recorded while paused.
  void pauseSession() {
    if (!state.isRunning || state.isPaused) return;
    state = state.copyWith(isPaused: true, pausedAt: DateTime.now());
  }

  /// Resumes a paused session, accumulating the paused interval.
  void resumeSession() {
    final DateTime? pausedAt = state.pausedAt;
    if (!state.isPaused || pausedAt == null) return;
    state = state.copyWith(
      isPaused: false,
      clearPausedAt: true,
      pausedDuration:
          state.pausedDuration + DateTime.now().difference(pausedAt),
    );
  }

  void stopSession() {
    if (state.session != null) {
      if (state.isPaused) resumeSession();
      final updatedSession = state.session!.copyWith(
        endTime: DateTime.now(),
        status: SessionStatus.completed,
        shots: state.shots,
        pausedDuration: state.pausedDuration,
      );
      state = state.copyWith(
        session: updatedSession,
        isRunning: false,
      );
    }
  }

  void addShot(ShotEvent shot) {
    if (state.isRunning && !state.isPaused && state.session != null) {
      final newShots = List<ShotEvent>.from(state.shots)..add(shot);
      state = state.copyWith(shots: newShots);
    }
  }

  void updateElapsed(Duration elapsed) {
    if (state.isRunning) {
      state = state.copyWith(elapsed: elapsed);
    }
  }

  void cancelSession() {
    if (state.session != null) {
      final updatedSession = state.session!.copyWith(
        endTime: DateTime.now(),
        status: SessionStatus.cancelled,
      );
      state = state.copyWith(
        session: updatedSession,
        isRunning: false,
      );
    }
  }
}

final sessionProvider =
    StateNotifierProvider<SessionNotifier, SessionState>((ref) {
  return SessionNotifier();
});
