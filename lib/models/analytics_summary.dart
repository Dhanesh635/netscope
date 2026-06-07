class AnalyticsSummary {
  const AnalyticsSummary({
    required this.averageRsrp,
    required this.averageRsrq,
    required this.averageSinr,
    required this.averageDownloadSpeed,
    required this.averageUploadSpeed,
    required this.bestRsrp,
    required this.worstRsrp,
    required this.totalSamples,
    required this.totalDistance,
    required this.averageVelocity,
    required this.sessionDuration,
  });

  const AnalyticsSummary.empty()
      : averageRsrp = 0,
        averageRsrq = 0,
        averageSinr = 0,
        averageDownloadSpeed = 0,
        averageUploadSpeed = 0,
        bestRsrp = 0,
        worstRsrp = 0,
        totalSamples = 0,
        totalDistance = 0,
        averageVelocity = 0,
        sessionDuration = Duration.zero;

  final double averageRsrp;
  final double averageRsrq;
  final double averageSinr;
  final double averageDownloadSpeed;
  final double averageUploadSpeed;
  final double bestRsrp;
  final double worstRsrp;
  final int totalSamples;
  final double totalDistance;
  final double averageVelocity;
  final Duration sessionDuration;

  bool get hasSamples => totalSamples > 0;
}
