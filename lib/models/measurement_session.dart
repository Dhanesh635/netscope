import 'network_measurement.dart';

class MeasurementSession {
  const MeasurementSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.measurements = const [],
  });

  final int id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<NetworkMeasurement> measurements;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
    };
  }

  factory MeasurementSession.fromMap(
    Map<String, Object?> map, {
    List<NetworkMeasurement> measurements = const [],
  }) {
    return MeasurementSession(
      id: map['id'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      endedAt: map['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
      measurements: measurements,
    );
  }
}