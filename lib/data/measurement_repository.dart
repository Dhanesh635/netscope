import 'package:flutter/foundation.dart';

import '../models/measurement_session.dart';
import '../models/network_measurement.dart';
import 'database_helper.dart';

class MeasurementRepository {
  MeasurementRepository({DatabaseHelper? databaseHelper})
    : _databaseHelper = databaseHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _databaseHelper;

  Future<int> createSession({DateTime? startedAt}) async {
    final db = await _databaseHelper.database;
    return db.insert(DatabaseHelper.sessionsTable, {
      'started_at': (startedAt ?? DateTime.now()).millisecondsSinceEpoch,
      'ended_at': null,
    });
  }

  Future<int> insertMeasurement(NetworkMeasurement measurement) async {
    final db = await _databaseHelper.database;
    final sessionId = measurement.sessionId;
    if (sessionId == null) {
      throw StateError('Cannot insert measurement: sessionId is null. IPC sync failed.');
    }

    final rowId = await db.insert(DatabaseHelper.measurementsTable, {
      ...measurement.toMap(),
      'session_id': sessionId,
    });
    debugPrint('[MeasurementRepo] INSERT row=$rowId session_id=$sessionId');
    return rowId;
  }

  Future<List<NetworkMeasurement>> getMeasurements({int? sessionId}) async {
    final db = await _databaseHelper.database;

    final rows = await db.query(
      DatabaseHelper.measurementsTable,
      where: sessionId == null ? null : 'session_id = ?',
      whereArgs: sessionId == null ? null : [sessionId],
      orderBy: 'timestamp ASC',
    );

    debugPrint('[MeasurementRepo] getMeasurements(session_id=$sessionId) → ${rows.length} rows');

    return rows
        .map((row) => NetworkMeasurement.fromMap(row))
        .toList(growable: false);
  }

  Future<MeasurementSession?> getSessionById(int sessionId) async {
    final db = await _databaseHelper.database;

    final sessionRows = await db.query(
      DatabaseHelper.sessionsTable,
      where: 'id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );

    if (sessionRows.isEmpty) {
      debugPrint('[MeasurementRepo] getSessionById($sessionId) → NOT FOUND');
      return null;
    }

    final measurements = await getMeasurements(sessionId: sessionId);
    return MeasurementSession.fromMap(
      sessionRows.first,
      measurements: measurements,
    );
  }

  Future<List<MeasurementSession>> getAllSessions() async {
    final db = await _databaseHelper.database;
    final sessionRows = await db.query(
      DatabaseHelper.sessionsTable,
      orderBy: 'started_at DESC',
    );

    final List<MeasurementSession> sessions = [];
    for (final row in sessionRows) {
      final sessionId = row['id'] as int;
      final measurements = await getMeasurements(sessionId: sessionId);
      sessions.add(MeasurementSession.fromMap(row, measurements: measurements));
    }
    return sessions;
  }

  Future<MeasurementSession?> getLatestSession() async {
    final db = await _databaseHelper.database;

    final sessionRows = await db.query(
      DatabaseHelper.sessionsTable,
      orderBy: 'started_at DESC, id DESC',
      limit: 1,
    );

    if (sessionRows.isEmpty) {
      return null;
    }

    final sessionId = sessionRows.first['id'] as int;
    return getSessionById(sessionId);
  }

  Future<int> deleteSession(int sessionId) async {
    final db = await _databaseHelper.database;
    return db.delete(
      DatabaseHelper.sessionsTable,
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<int> closeSession(int sessionId, {DateTime? endedAt}) async {
    final db = await _databaseHelper.database;

    return db.update(
      DatabaseHelper.sessionsTable,
      {'ended_at': (endedAt ?? DateTime.now()).millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Diagnostic dump — prints raw SQL query results for debugging.
  Future<void> debugDumpDiagnostics({int? forSessionId}) async {
    final db = await _databaseHelper.database;

    // Phase 1: Total counts
    final totalMeasurements = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseHelper.measurementsTable}',
    );
    debugPrint('[DB DIAGNOSTIC] SELECT COUNT(*) FROM measurements = ${totalMeasurements.first['cnt']}');

    final totalSessions = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseHelper.sessionsTable}',
    );
    debugPrint('[DB DIAGNOSTIC] SELECT COUNT(*) FROM sessions = ${totalSessions.first['cnt']}');

    // Phase 3: Per-session counts
    final perSession = await db.rawQuery(
      'SELECT session_id, COUNT(*) as cnt FROM ${DatabaseHelper.measurementsTable} GROUP BY session_id',
    );
    for (final row in perSession) {
      debugPrint('[DB DIAGNOSTIC] session_id=${row['session_id']} → ${row['cnt']} measurements');
    }

    // Specific session audit
    if (forSessionId != null) {
      final sessionCount = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM ${DatabaseHelper.measurementsTable} WHERE session_id = ?',
        [forSessionId],
      );
      debugPrint('[DB DIAGNOSTIC] Session $forSessionId has ${sessionCount.first['cnt']} measurements');
    }

    // Phase 2: First 10 rows
    final sampleRows = await db.rawQuery(
      'SELECT id, session_id, timestamp, rsrp, latitude, longitude FROM ${DatabaseHelper.measurementsTable} ORDER BY id DESC LIMIT 10',
    );
    debugPrint('[DB DIAGNOSTIC] Last 10 measurement rows:');
    for (final row in sampleRows) {
      debugPrint('[DB DIAGNOSTIC]   id=${row['id']} session_id=${row['session_id']} '
          'timestamp=${row['timestamp']} rsrp=${row['rsrp']} '
          'lat=${row['latitude']} lng=${row['longitude']}');
    }

    // Database path for reference
    debugPrint('[DB DIAGNOSTIC] Database path: ${db.path}');
  }
}

