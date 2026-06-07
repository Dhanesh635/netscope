import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:netscope/data/measurement_repository.dart';
import 'package:netscope/models/measurement_session.dart';
import 'package:netscope/models/network_measurement.dart';
import 'package:netscope/services/export_service.dart';

class FakeMeasurementRepository extends MeasurementRepository {
  FakeMeasurementRepository(this.session);

  final MeasurementSession? session;

  @override
  Future<MeasurementSession?> getLatestSession() async => session;

  @override
  Future<MeasurementSession?> getSessionById(int sessionId) async {
    if (session?.id == sessionId) {
      return session;
    }

    return null;
  }
}

void main() {
  test('exports a complete drive test session to csv', () async {
    final tempDirectory = await Directory.systemTemp.createTemp('netscope_export_test_');
    addTearDown(() async {
      if (await tempDirectory.exists()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    final session = MeasurementSession(
      id: 42,
      startedAt: DateTime(2026, 6, 2, 12, 0),
      endedAt: DateTime(2026, 6, 2, 12, 5),
      measurements: [
        NetworkMeasurement(
          id: 1,
          sessionId: 42,
          timestamp: DateTime(2026, 6, 2, 12, 1),
          latitude: 37.0,
          longitude: -122.0,
          rsrp: -92,
          rsrq: -11,
          sinr: 14.5,
          download: 21.3,
          upload: 8.4,
          pci: 123,
          carrier: 'Test Carrier',
          networkType: '5G NR',
          velocity: 4.2,
        ),
      ],
    );

    final exportService = ExportService(
      measurementRepository: FakeMeasurementRepository(session),
      documentsDirectoryProvider: () async => tempDirectory,
    );

    final exportedPath = await exportService.exportSession(session.id);
    final exportedFile = File(exportedPath);
    final contents = await exportedFile.readAsString();

    expect(contents, contains('timestamp,latitude,longitude,rsrp,rsrq,sinr,download,upload,pci,carrier,networkType,velocity'));
    expect(contents, contains('2026-06-02T12:01:00.000'));
    expect(contents, contains('37.0,-122.0,-92.0,-11.0,14.5,21.3,8.4,123,Test Carrier,5G NR,4.2'));
  });
}
