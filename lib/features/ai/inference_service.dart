import 'prediction_model.dart';

/// Abstract Edge ML Inference Service
///
/// Ensures strict separation between UI/Business Logic and the underlying AI runtime.
abstract class MLInferenceService {
  /// Initialize edge model interpreter/weights
  Future<void> initializeModel();

  /// Run forward inference on 16-dimensional feature vector
  Future<PredictionResult> runInference(List<double> featureVector);

  /// Cleanup native tensors and memory
  void dispose();
}
