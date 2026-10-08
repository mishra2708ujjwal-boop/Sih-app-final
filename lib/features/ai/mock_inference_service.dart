import 'dart:math';
import 'inference_service.dart';
import 'prediction_model.dart';

/// On-device risk inference: five hand-tuned logistic regressions.
///
/// This is the model that actually runs. Each of the five risk domains is a
/// sigmoid over a weighted sum of the 16-feature vector — logistic regression,
/// one layer, no hidden units and no learned weights. The coefficients below
/// were chosen by hand from published physiological thresholds, not fitted to a
/// dataset, so treat the outputs as a defensible heuristic rather than a
/// validated prediction.
///
/// It is named "Mock" because it stands in for the TFLite runner described in
/// `tflite_inference_service.dart`, not because the arithmetic is fake: it runs
/// for real, on device, with no network. Nothing downstream of this class is
/// simulated.
class MockInferenceService implements MLInferenceService {
  bool _isInitialized = false;

  @override
  Future<void> initializeModel() async {
    // Simulate local model asset loading into memory
    await Future.delayed(const Duration(milliseconds: 150));
    _isInitialized = true;
  }

  @override
  Future<PredictionResult> runInference(List<double> features) async {
    if (!_isInitialized) {
      await initializeModel();
    }

    // Unpack features according to FeatureProcessor schema:
    // f0: hrNorm, f1: hrDev, f2: spo2Norm, f3: spo2Drop, f4: tempNorm, f5: tempDev,
    // f6: activity, f7: sleepDur, f8: sleepQual, f9: envTemp, f10: humidity,
    // f11: aqi, f12: heatIndex, f13: exposure, f14: hrv, f15: trendSlope

    final f1Hrdev = features.length > 1 ? features[1] : 0.0;
    final f2Spo2norm = features.length > 2 ? features[2] : 0.9;
    final f3Spo2drop = features.length > 3 ? features[3] : 0.0;
    final f5Tempdev = features.length > 5 ? features[5] : 0.0;
    final f7Sleepdur = features.length > 7 ? features[7] : 1.0;
    final f8Sleepqual = features.length > 8 ? features[8] : 0.8;
    final f11Aqi = features.length > 11 ? features[11] : 0.1;
    final f12Heatindex = features.length > 12 ? features[12] : 0.4;
    final f13Exposure = features.length > 13 ? features[13] : 0.1;
    final f14Hrv = features.length > 14 ? features[14] : 0.5;

    // 1. Heat Stress Probability (Non-linear sigmoid of thermal & cardiac strain)
    final heatLogit = -2.8 +
        (3.5 * f12Heatindex) +
        (2.2 * f13Exposure) +
        (2.8 * max(0.0, f1Hrdev)) +
        (3.0 * max(0.0, f5Tempdev));
    final heatStressProb = _sigmoid(heatLogit);

    // 2. Dehydration Risk Probability
    final dehydLogit = -3.2 +
        (2.8 * f12Heatindex) +
        (2.5 * f13Exposure) +
        (1.5 * max(0.0, f1Hrdev));
    final dehydProb = _sigmoid(dehydLogit);

    // 3. Fatigue Risk Probability
    final sleepDeficit = max(0.0, 1.0 - f7Sleepdur);
    final sleepQualityDeficit = max(0.0, 1.0 - f8Sleepqual);
    final hrvDeficit = max(0.0, 0.6 - f14Hrv);
    final fatigueLogit = -2.5 +
        (3.2 * sleepDeficit) +
        (2.6 * sleepQualityDeficit) +
        (2.0 * hrvDeficit) +
        (1.2 * max(0.0, f1Hrdev));
    final fatigueProb = _sigmoid(fatigueLogit);

    // 4. Respiratory Risk Probability (Driven by AQI + SpO2 drop)
    final respLogit = -3.5 +
        (5.2 * f11Aqi) +
        (4.8 * f3Spo2drop) +
        (2.5 * max(0.0, 0.8 - f2Spo2norm));
    final respProb = _sigmoid(respLogit);

    // 5. Cardiovascular Risk Probability
    final cardioLogit = -3.0 +
        (4.0 * max(0.0, f1Hrdev)) +
        (2.5 * max(0.0, f5Tempdev)) +
        (2.2 * hrvDeficit);
    final cardioProb = _sigmoid(cardioLogit);

    // 6. Overall Anomaly Probability
    final anomalyLogit = -3.0 +
        (2.5 * heatStressProb) +
        (2.2 * respProb) +
        (2.2 * cardioProb) +
        (1.8 * fatigueProb);
    final overallAnomaly = _sigmoid(anomalyLogit);

    return PredictionResult(
      heatStressProbability: double.parse(heatStressProb.toStringAsFixed(3)),
      dehydrationRiskProbability: double.parse(dehydProb.toStringAsFixed(3)),
      fatigueProbability: double.parse(fatigueProb.toStringAsFixed(3)),
      respiratoryRiskProbability: double.parse(respProb.toStringAsFixed(3)),
      cardiovascularRiskProbability: double.parse(cardioProb.toStringAsFixed(3)),
      overallAnomalyProbability: double.parse(overallAnomaly.toStringAsFixed(3)),
      timestamp: DateTime.now(),
    );
  }

  double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  @override
  void dispose() {}
}
