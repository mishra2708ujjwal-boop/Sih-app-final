# PRANA TFLite Model Specifications

## Placeholder Status — read this before quoting the app's capabilities
**No trained model ships with this app.** `prana_risk_model.tflite` is a text
placeholder holding the intended file path, not a FlatBuffer; `tflite_flutter`
is not in `pubspec.yaml`, and `TFLiteInferenceService` is never instantiated.

What actually runs is `lib/features/ai/mock_inference_service.dart`: five
**hand-tuned logistic regressions** (a sigmoid over a weighted sum of the
feature vector below) evaluated in Dart, on device, with no network. The
coefficients were chosen by hand, not learned from data.

The tensor spec below is the contract a future trained model must satisfy — it
describes what `FeatureProcessor` already emits, so a real `.tflite` can be
dropped in without touching the pipeline.

## Model Input Tensor:
- **Shape**: `[1, 16]` (float32)
- **Feature Vector Index Mapping**:
  0. Normalized Heart Rate `(HR - 40) / (200 - 40)`
  1. Heart Rate Baseline Deviation Ratio `(HR - HR_baseline_mean) / HR_baseline_std`
  2. Normalized SpO₂ `(SpO2 - 70) / (100 - 70)`
  3. SpO₂ Baseline Deviation `(SpO2_baseline_min - SpO2)`
  4. Normalized Body Temperature `(Temp - 34.0) / (42.0 - 34.0)`
  5. Body Temperature Baseline Deviation `(Temp - Temp_baseline_mean)`
  6. Normalized Activity Level `(0.0 = Rest, 0.5 = Moderate, 1.0 = High)`
  7. Sleep Duration Ratio `(LastNightSleepHours / 8.0)`
  8. Sleep Quality Score `(0.0 - 1.0)`
  9. Ambient Temperature `(EnvTemp - (-10.0)) / (55.0 - (-10.0))`
  10. Ambient Humidity `(EnvHumidity / 100.0)`
  11. Air Quality Index `(AQI / 500.0)`
  12. Heat Exposure Index `(HeatIndex / 60.0)`
  13. Heat Exposure Duration in hours `(DurationHours / 12.0)`
  14. Heart Rate Variability `(HRV_RMSSD / 150.0)`
  15. Biometric Slope / Rate of Change over 15 mins `(dHR/dt)`

## Model Output Tensor:
- **Shape**: `[1, 6]` (float32, Sigmoid probabilities [0.0 - 1.0])
  0. `heatStressProbability`
  1. `dehydrationRiskProbability`
  2. `fatigueProbability`
  3. `respiratoryRiskProbability`
  4. `cardiovascularRiskProbability`
  5. `overallAnomalyProbability`

## Production Replacement:
To deploy your trained PyTorch / TensorFlow Keras model:
1. Train model on clinical/physiological dataset (e.g. MIMIC-III, WESAD, or simulated edge sensor dataset).
2. Convert model via `tf.lite.TFLiteConverter.from_keras_model(model)` with float16 or int8 quantization.
3. Overwrite `assets/models/prana_risk_model.tflite` with your generated `.tflite` binary.
4. Enable `TFLiteInferenceService` in `lib/features/ai/inference_service.dart`.
