import 'package:tflite_flutter/tflite_flutter.dart';

import 'feature_schema.dart';
import 'inference_service.dart';
import 'prediction_model.dart';

/// Production TensorFlow Lite inference service for PRANA.
///
/// Model contract:
///   Input  : [1, 22]
///            11 physiological features + 11 availability masks
///
///   Output : [1, 11]
///            reconstructed physiological features
///
/// The model is an autoencoder. It does not directly output six disease
/// probabilities. Anomaly risk is therefore calculated from the masked
/// reconstruction error.
class TFLiteInferenceService implements MLInferenceService {
  final String modelPath;

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  /// P95 reconstruction error measured on the held-out test set.
  ///
  /// Errors at or above this value are treated as maximum anomaly score.
  static const double _p95ReconstructionError = 0.02626;

  TFLiteInferenceService({
    this.modelPath = 'assets/models/prana_autoencoder_best.tflite',
  });

  @override
  Future<void> initializeModel() async {
    if (_isModelLoaded) {
      return;
    }

    _interpreter = await Interpreter.fromAsset(modelPath);

    final inputShape = _interpreter!.getInputTensor(0).shape;
    final outputShape = _interpreter!.getOutputTensor(0).shape;

    if (inputShape.length != 2 || inputShape[1] != 22) {
      _interpreter!.close();
      _interpreter = null;

      throw StateError(
        'Invalid PRANA model input shape: $inputShape. '
        'Expected [1, 22].',
      );
    }

    if (outputShape.length != 2 || outputShape[1] != 11) {
      _interpreter!.close();
      _interpreter = null;

      throw StateError(
        'Invalid PRANA model output shape: $outputShape. '
        'Expected [1, 11].',
      );
    }

    _isModelLoaded = true;
  }

  @override
  Future<PredictionResult> runInference(List<double> featureVector) async {
    if (!_isModelLoaded) {
      await initializeModel();
    }

    if (featureVector.length != FeatureSchema.featureCount) {
      throw ArgumentError(
        'PRANA FeatureProcessor must produce exactly '
        '${FeatureSchema.featureCount} features. '
        'Received ${featureVector.length}.',
      );
    }

    final interpreter = _interpreter;

    if (interpreter == null) {
      throw StateError('TFLite interpreter is not initialized.');
    }

    /*
     * FeatureProcessor produces the frozen 16-feature application schema:
     *
     *  0  normalized HR
     *  1  HR baseline deviation
     *  2  normalized SpO2
     *  3  SpO2 baseline drop
     *  4  normalized body temperature
     *  5  body temperature deviation
     *  6  activity level
     *  7  sleep duration ratio
     *  8  sleep quality
     *  9  ambient temperature
     * 10  humidity
     * 11  AQI
     * 12  heat index
     * 13  heat exposure duration
     * 14  HRV RMSSD
     * 15  HR trend slope
     *
     * The trained model uses only the 11 physiological features:
     *
     *  0,1,2,3,4,5,6,7,8,14,15
     *
     * followed by an 11-bit availability mask.
     */

    final physiologicalFeatures = <double>[
      featureVector[0],
      featureVector[1],
      featureVector[2],
      featureVector[3],
      featureVector[4],
      featureVector[5],
      featureVector[6],
      featureVector[7],
      featureVector[8],
      featureVector[14],
      featureVector[15],
    ];

    /*
     * At this integration boundary the FeatureProcessor has already supplied
     * usable values for the application. The live PRANA hardware currently
     * provides the physiological channels represented by the first 11 model
     * features, while sleep is not measured on hardware.
     *
     * Therefore sleep features (indices 7 and 8) are marked unavailable when
     * the service is used by the real controller.
     *
     * The current controller exposes demo sleep data separately through
     * hasSleepData. Until the controller passes explicit availability metadata,
     * the model mask is kept conservative here.
     */
    final mask = <double>[
      1.0, // normalized HR - available from BLE
      1.0, // HR baseline deviation - derived from real HR
      1.0, // normalized SpO2 - available from BLE
      1.0, // SpO2 baseline drop - derived from real SpO2
      1.0, // normalized body temperature - available from BLE
      1.0, // body temperature deviation - derived from real temperature
      0.0, // activity level - currently hardcoded, not real sensor data
      0.0, // sleep duration - unavailable
      0.0, // sleep quality - unavailable
      0.0, // HRV RMSSD - currently hardcoded, not real sensor data
      1.0, // HR trend slope - derived from real HR history
    ];

    final modelInput = <List<double>>[
      <double>[...physiologicalFeatures, ...mask],
    ];

    final modelOutput = List<List<double>>.generate(
      1,
      (_) => List<double>.filled(11, 0.0),
    );

    interpreter.run(modelInput, modelOutput);

    final reconstruction = modelOutput[0];

    final reconstructionError = _calculateMaskedReconstructionError(
      physiologicalFeatures,
      reconstruction,
      mask,
    );

    final anomalyScore = _calculateAnomalyScore(reconstructionError);

    return PredictionResult(
      heatStressProbability: anomalyScore,
      dehydrationRiskProbability: anomalyScore,
      fatigueProbability: anomalyScore,
      respiratoryRiskProbability: anomalyScore,
      cardiovascularRiskProbability: anomalyScore,
      overallAnomalyProbability: anomalyScore,
      timestamp: DateTime.now(),
      // Real count from the mask actually used above -- not a hardcoded
      // "16 signals" claim. Today this is 9/11 (activity_level and
      // hrv_rmssd are still hardcoded absent in the mask above); this
      // number moves automatically once those are wired to real sensors,
      // so the UI can never silently go stale the way risk.confidence did.
      signalsAvailable: mask.where((m) => m > 0.0).length,
      signalsTotal: mask.length,
    );
  }

  /// Calculates the same masked MSE used during model validation.
  double _calculateMaskedReconstructionError(
    List<double> input,
    List<double> reconstruction,
    List<double> mask,
  ) {
    double squaredError = 0.0;
    double observedFeatures = 0.0;

    for (var i = 0; i < input.length; i++) {
      if (mask[i] <= 0.0) {
        continue;
      }

      final difference = input[i] - reconstruction[i];
      squaredError += difference * difference;
      observedFeatures += mask[i];
    }

    if (observedFeatures == 0.0) {
      return 0.0;
    }

    return squaredError / observedFeatures;
  }

  /// Converts reconstruction error into the existing app's 0..1 risk scale.
  ///
  /// This is an anomaly score, not a medically calibrated probability.
  double _calculateAnomalyScore(double reconstructionError) {
    if (reconstructionError <= 0.0) {
      return 0.0;
    }

    return (reconstructionError / _p95ReconstructionError)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  @override
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isModelLoaded = false;
  }
}
