import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/measurement_repository.dart';
import '../models/measurement_session.dart';

class ExportService {
  ExportService({
    MeasurementRepository? measurementRepository,
    Future<Directory> Function()? documentsDirectoryProvider,
  })  : _measurementRepository = measurementRepository ?? MeasurementRepository(),
        _documentsDirectoryProvider =
            documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final MeasurementRepository _measurementRepository;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<String?> exportLatestSession({bool share = false}) async {
    final session = await _measurementRepository.getLatestSession();
    if (session == null) {
      debugPrint('[ExportService] No sessions found to export.');
      return null;
    }

    return exportSession(session.id, share: share);
  }

  Future<String> exportSession(int sessionId, {bool share = false}) async {
    debugPrint('[ExportService] Export started for session $sessionId');

    // Phase 1-3 diagnostic dump: raw SQL state before export
    await _measurementRepository.debugDumpDiagnostics(forSessionId: sessionId);

    final session = await _requireSession(sessionId);
    debugPrint('[ExportService] Loaded ${session.measurements.length} measurements');

    final file = await _writeSessionCsv(session);

    final fileSize = await file.length();
    debugPrint('[ExportService] File written: ${file.path}');
    debugPrint('[ExportService] File size: $fileSize bytes');

    if (share) {
      debugPrint('[ExportService] Share launched');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Drive Test Session ${session.id}',
        ),
      );
    }

    return file.path;
  }

  Future<MeasurementSession> _requireSession(int sessionId) async {
    final session = await _measurementRepository.getSessionById(sessionId);
    if (session == null) {
      throw StateError('Drive test session $sessionId was not found.');
    }

    return session;
  }

  Future<File> _writeSessionCsv(MeasurementSession session) async {
    final directory = await _exportDirectory();
    final fileName = _fileNameForSession(session);
    final file = File('${directory.path}${Platform.pathSeparator}$fileName');

    final converter = const ListToCsvConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      eol: '\n',
    );

    final rows = <List<dynamic>>[
      <dynamic>[
        'timestamp',
        'deviceid',
        'devicemake',
        'deviceModel',
        'carrier',
        'networktype',
        'RSRP',
        'RSRQ',
        'SINR',
        'PCI',
        'download',
        'upload',
        'velocity',
        'latitude',
        'longitude',
      ],
      ...session.measurements.map(
        (measurement) => <dynamic>[
          measurement.timestamp.toIso8601String(),
          measurement.deviceId,
          measurement.deviceMake,
          measurement.deviceModel,
          measurement.carrier,
          measurement.networkType,
          measurement.rsrp,
          measurement.rsrq,
          measurement.sinr,
          measurement.pci,
          measurement.download,
          measurement.upload,
          measurement.velocity,
          measurement.latitude,
          measurement.longitude,
        ],
      ),
    ];

    final csvDataRowCount = rows.length - 1; // exclude header
    debugPrint('[ExportService] CSV generated: $csvDataRowCount data rows');

    // Log header + first/last 3 rows for manual validation
    if (rows.isNotEmpty) {
      debugPrint('[ExportService] Header: ${rows[0]}');
      for (var i = 1; i <= 3 && i < rows.length; i++) {
        debugPrint('[ExportService] Row $i: ${rows[i]}');
      }
      for (var i = rows.length - 3; i < rows.length && i > 3; i++) {
        debugPrint('[ExportService] Row $i: ${rows[i]}');
      }
    }

    try {
      final baseDirectory = await _documentsDirectoryProvider();
      final errFile = File('${baseDirectory.path}/db_errors.txt');
      if (await errFile.exists()) {
        rows.add([await errFile.readAsString()]);
        await errFile.delete();
      }
    } catch (_) {}

    await file.writeAsString(converter.convert(rows), flush: true);
    return file;
  }

  Future<Directory> _exportDirectory() async {
    final baseDirectory = await _documentsDirectoryProvider();
    final exportDirectory = Directory('${baseDirectory.path}${Platform.pathSeparator}exports');
    if (!await exportDirectory.exists()) {
      await exportDirectory.create(recursive: true);
    }

    return exportDirectory;
  }

  String _fileNameForSession(MeasurementSession session) {
    final startedAtStamp = session.startedAt.toIso8601String().replaceAll(':', '-');
    return 'drive_test_session_${session.id}_$startedAtStamp.csv';
  }
}
