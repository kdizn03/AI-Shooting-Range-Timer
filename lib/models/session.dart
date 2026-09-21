import 'package:equatable/equatable.dart';

import 'firearm_profile.dart';
import 'shot_event.dart';

/// Possible states of a shooting session.
enum SessionStatus {
  /// Session is being configured before starting.
  setup,

  /// Session is actively running and detecting shots.
  active,

  /// Session has been completed normally by the user.
  completed,

  /// Session was cancelled before completion.
  cancelled,
}

/// Represents a complete shooting practice session.
///
/// A [Session] tracks the timeline from start to finish, including
/// all detected [ShotEvent]s, the session's status lifecycle, and
/// the configured [FirearmProfile].
class Session extends Equatable {
  /// Creates a new [Session].
  const Session({
    required this.id,
    required this.startTime,
    this.endTime,
    this.shots = const [],
    this.status = SessionStatus.setup,
    this.firearmProfile = FirearmProfile.glock19Unsuppressed,
  });

  /// Unique identifier for this session (UUID).
  final String id;

  /// Wall-clock time when the session was started (beep sounded).
  final DateTime startTime;

  /// Wall-clock time when the session was stopped.
  ///
  /// `null` if the session is still active or in setup.
  final DateTime? endTime;

  /// Chronologically ordered list of detected shot events.
  final List<ShotEvent> shots;

  /// Current lifecycle status of the session.
  final SessionStatus status;

  /// The firearm profile configured for this session (e.g. Glock 19 Unsuppressed vs Suppressed).
  final FirearmProfile firearmProfile;

  /// Whether the session is currently running.
  bool get isActive => status == SessionStatus.active;

  /// Whether the session has ended (completed or cancelled).
  bool get isFinished =>
      status == SessionStatus.completed || status == SessionStatus.cancelled;

  /// Total number of shots detected in this session.
  int get shotCount => shots.length;

  /// Duration of the session from start to end (or now if active).
  Duration get duration {
    final DateTime end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  /// The most recently detected shot, or `null` if none.
  ShotEvent? get lastShot => shots.isEmpty ? null : shots.last;

  /// Creates a copy of this [Session] with the given fields replaced.
  Session copyWith({
    String? id,
    DateTime? startTime,
    DateTime? endTime,
    List<ShotEvent>? shots,
    SessionStatus? status,
    FirearmProfile? firearmProfile,
  }) {
    return Session(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      shots: shots ?? this.shots,
      status: status ?? this.status,
      firearmProfile: firearmProfile ?? this.firearmProfile,
    );
  }

  /// Adds a [ShotEvent] to this session, returning a new [Session].
  Session addShot(ShotEvent shot) {
    return copyWith(shots: [...shots, shot]);
  }

  /// Serializes this [Session] to a JSON-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'shots': shots.map((s) => s.toMap()).toList(),
      'status': status.name,
      'firearmProfile': firearmProfile.toMap(),
    };
  }

  /// Deserializes a [Session] from a JSON-compatible map.
  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'] as String,
      startTime: DateTime.parse(map['startTime'] as String),
      endTime: map['endTime'] != null
          ? DateTime.parse(map['endTime'] as String)
          : null,
      shots: (map['shots'] as List<dynamic>)
          .map((s) => ShotEvent.fromMap(s as Map<String, dynamic>))
          .toList(),
      status: SessionStatus.values.byName(map['status'] as String),
      firearmProfile: map['firearmProfile'] != null
          ? FirearmProfile.fromMap(map['firearmProfile'] as Map<String, dynamic>)
          : FirearmProfile.glock19Unsuppressed,
    );
  }

  @override
  List<Object?> get props =>
      [id, startTime, endTime, shots, status, firearmProfile];

  @override
  String toString() =>
      'Session(id: $id, shots: $shotCount, status: $status, profile: ${firearmProfile.displayName})';
}
