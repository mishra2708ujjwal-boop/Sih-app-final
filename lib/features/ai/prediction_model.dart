/// Output tensor representation from On-Device Edge ML inference
class PredictionResult {
  final double heatStressProbability;        // 0.0 - 1.0
  final double dehydrationRiskProbability;   // 0.0 - 1.0
  final double fatigueProbability;           // 0.0 - 1.0
  final double respiratoryRiskProbability;   // 0.0 - 1.0
  final double cardiovascularRiskProbability;// 0.0 - 1.0
  final double overallAnomalyProbability;    // 0.0 - 1.0
  final DateTime timestamp;

  /// How many of [signalsTotal] model inputs were real sensor data for this
  /// prediction, vs. masked-absent. Populated from the actual inference
  /// mask by TFLiteInferenceService; defaults to "fully available" for the
  /// mock/demo path, which has no mask concept of its own.
  final int signalsAvailable;
  final int signalsTotal;

  const PredictionResult({
    required this.heatStressProbability,
    required this.dehydrationRiskProbability,
    required this.fatigueProbability,
    required this.respiratoryRiskProbability,
    required this.cardiovascularRiskProbability,
    required this.overallAnomalyProbability,
    required this.timestamp,
    this.signalsAvailable = 11,
    this.signalsTotal = 11,
  });

  factory PredictionResult.initial() {
    return PredictionResult(
      heatStressProbability: 0.05,
      dehydrationRiskProbability: 0.08,
      fatigueProbability: 0.12,
      respiratoryRiskProbability: 0.04,
      cardiovascularRiskProbability: 0.06,
      overallAnomalyProbability: 0.05,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'heatStressProbability': heatStressProbability,
        'dehydrationRiskProbability': dehydrationRiskProbability,
        'fatigueProbability': fatigueProbability,
        'respiratoryRiskProbability': respiratoryRiskProbability,
        'cardiovascularRiskProbability': cardiovascularRiskProbability,
        'overallAnomalyProbability': overallAnomalyProbability,
        'timestamp': timestamp.toIso8601String(),
        'signalsAvailable': signalsAvailable,
        'signalsTotal': signalsTotal,
      };
}
