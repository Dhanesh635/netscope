import 'package:flutter_test/flutter_test.dart';
import 'package:netscope/models/network_measurement.dart';
import 'package:netscope/services/analytics_service.dart';

void main() {
  test('summarizes a measurement session', () {
    final measurements = [
      NetworkMeasurement(
        timestamp: DateTime(2026, 6, 2, 12, 0, 0),
        latitude: 37.0,
        longitude: -122.0,
        rsrp: -110,
        rsrq: -16,
        sinr: 10,
        download: 100,
        upload: 20,
        pci: 10,
        carrier: 'Carrier A',
        networkType: '5G NR',
        velocity: 5,
      ),
      NetworkMeasurement(
        timestamp: DateTime(2026, 6, 2, 12, 1, 0),
        latitude: 37.0009,
        longitude: -122.0009,
        rsrp: -95,
        rsrq: -12,
        sinr: 20,
        download: 200,
        upload: 30,
        pci: 11,
        carrier: 'Carrier A',
        networkType: '5G NR',
        velocity: 7,
      ),
    ];

    final summary = const AnalyticsService().summarize(measurements);

    expect(summary.totalSamples, 2);
    expect(summary.averageRsrp, closeTo(-102.5, 0.0001));
    expect(summary.averageRsrq, closeTo(-14.0, 0.0001));
    expect(summary.averageSinr, closeTo(15.0, 0.0001));
    expect(summary.averageDownloadSpeed, closeTo(150.0, 0.0001));
    expect(summary.averageUploadSpeed, closeTo(25.0, 0.0001));
    expect(summary.bestRsrp, closeTo(-95.0, 0.0001));
    expect(summary.worstRsrp, closeTo(-110.0, 0.0001));
    expect(summary.totalDistance, greaterThan(0));
    expect(summary.averageVelocity, closeTo(6.0, 0.0001));
    expect(summary.sessionDuration, const Duration(minutes: 1));
  });

  test('returns an empty summary for no measurements', () {
    final summary = const AnalyticsService().summarize(const []);

    expect(summary.totalSamples, 0);
    expect(summary.sessionDuration, Duration.zero);
    expect(summary.totalDistance, 0);
    expect(summary.hasSamples, isFalse);
  });
}
