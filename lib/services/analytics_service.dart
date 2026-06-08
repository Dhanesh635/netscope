import 'package:geolocator/geolocator.dart';

import '../models/analytics_summary.dart';
import '../models/network_measurement.dart';

class AnalyticsService {
  const AnalyticsService();

  AnalyticsSummary summarize(List<NetworkMeasurement> measurements) {
    if (measurements.isEmpty) {
      return const AnalyticsSummary.empty();
    }

    final orderedMeasurements = List<NetworkMeasurement>.of(measurements)
      ..sort((left, right) => left.timestamp.compareTo(right.timestamp));

    var totalRsrp = 0.0;
    var totalRsrq = 0.0;
    var totalSinr = 0.0;
    var sinrCount = 0;
    var totalDownload = 0.0;
    var totalUpload = 0.0;
    var totalVelocity = 0.0;
    var totalDistance = 0.0;

    for (var index = 0; index < orderedMeasurements.length; index++) {
      final measurement = orderedMeasurements[index];
      totalRsrp += measurement.rsrp;
      totalRsrq += measurement.rsrq;
      if (measurement.sinr != null) {
        totalSinr += measurement.sinr!;
        sinrCount++;
      }
      totalDownload += measurement.download;
      totalUpload += measurement.upload;
      totalVelocity += measurement.velocity;

      if (index == 0) {
        continue;
      }

      final previous = orderedMeasurements[index - 1];
      totalDistance += Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        measurement.latitude,
        measurement.longitude,
      );
    }

    final sampleCount = orderedMeasurements.length;
    final sessionDuration = orderedMeasurements.last.timestamp.difference(
      orderedMeasurements.first.timestamp,
    );

    return AnalyticsSummary(
      averageRsrp: totalRsrp / sampleCount,
      averageRsrq: totalRsrq / sampleCount,
      averageSinr: sinrCount > 0 ? totalSinr / sinrCount : 0.0,
      averageDownloadSpeed: totalDownload / sampleCount,
      averageUploadSpeed: totalUpload / sampleCount,
      bestRsrp: orderedMeasurements.map((measurement) => measurement.rsrp).reduce((current, candidate) => candidate > current ? candidate : current),
      worstRsrp: orderedMeasurements.map((measurement) => measurement.rsrp).reduce((current, candidate) => candidate < current ? candidate : current),
      totalSamples: sampleCount,
      totalDistance: totalDistance,
      averageVelocity: totalVelocity / sampleCount,
      sessionDuration: sessionDuration.isNegative ? Duration.zero : sessionDuration,
    );
  }
}
