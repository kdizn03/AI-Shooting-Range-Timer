import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/firearm_profile.dart';
import '../models/session.dart';
import '../models/shot_event.dart';

class SessionState {
  final Session? session;
  final bool isRunning;
  final Duration elapsed;
  final List<ShotEvent> shots;

  SessionState({
    this.session,
    this.isRunning = false,
    this.elapsed = Duration.zero,
    this.shots = const [],
  });

  SessionState copyWith({
    Session? session,
    bool? isRunning,
    Duration? elapsed,
    List<ShotEvent>? shots,
  }) {
    return SessionState(
      session: session ?? this.session,
      isRunning: isRunning ?? this.isRunning,
      elapsed: elapsed ?? this.elapsed,
      shots: shots ?? this.shots,
    );
  }
}

class SessionNotifier extends StateNotifier<SessionState> {
  SessionNotifier() : super(SessionState());

  void startSession(
      {FirearmProfile firearmProfile = FirearmProfile.glock19Unsuppressed}) {
    final session = Session(
      id: const Uuid().v4(),
      startTime: DateTime.now(),
      status: SessionStatus.active,
      firearmProfile: firearmProfile,
    );
    state = SessionState(session: session, isRunning: true);
  }

  void stopSession() {
    if (state.session != null) {
      final updatedSession = state.session!.copyWith(
        endTime: DateTime.now(),
        status: SessionStatus.completed,
        shots: state.shots,
      );
      state = state.copyWith(
        session: updatedSession,
        isRunning: false,
      );
    }
  }

  void addShot(ShotEvent shot) {
    if (state.isRunning && state.session != null) {
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
