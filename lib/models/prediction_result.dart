class PredictionResult {
  final double probability;
  final String prediction;
  final String riskLevel;
  final double confidence;
  final double qosScore;

  PredictionResult({
    required this.probability,
    required this.prediction,
    required this.riskLevel,
    required this.confidence,
    required this.qosScore,
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      probability: (json["handover_probability"] as num).toDouble(),
      prediction: json["prediction"],
      riskLevel: json["risk_level"],
      confidence: (json["confidence"] as num).toDouble(),
      qosScore: (json["qos_score"] as num).toDouble(),
    );
  }
}