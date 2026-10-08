import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../ai/inference_service.dart';
import '../ai/prediction_model.dart';
import 'autoencoder.dart';
import 'personal_model.dart';
import 'personalization_status.dart';
import 'vitals_sample_store.dart';

/// Drop-in [MLInferenceService] that layers per-person personalization on top
/// of an existing population model — without the controller knowing anything
/// changed. It is injected via `PranaHealthController(customMlService: ...)`,
/// the same seam the TFLite runner was always meant to use.
///
/// Each tick it:
///  1. runs the [_fallback] population model (the cold-start prior),
///  2. if the reading is calm and on-baseline, folds it into [_model] (training)
///     and stores it in the [_store] (the individual's vitals database),
///  3. blends the population and personal anomaly by how much it has learned,
///  4. applies hard physiological floors so personalization can never *hide* a
///     genuine emergency,
///  5. returns the adjusted prediction.
///
/// Phase 1 personalizes the overall anomaly signal (the field the risk engine
/// weights and surfaces). Per-domain personalization and the on-device
/// autoencoder are Phase 2 and slot in behind this same class.
class PersonalizedInferenceService implements MLInferenceService {
  PersonalizedInferenceService(
    this._fallback,
    this._store,
    this._model, [
    this._config = const PersonalizationConfig.demo(),
  ]) {
    _status = ValueNotifier<PersonalizationStatus>(_buildStatus());
    _lastStage = _status.value.stage;
    // Resume the deep model from disk (if any) off the hot path.
    unawaited(_loadDeepModel());
  }

  final MLInferenceService _fallback;
  final VitalsSampleStore _store;
  final PersonalModel _model;
  final PersonalizationConfig _config;

  /// Ceiling on how much the deep autoencoder can override the Gaussian, so the
  /// simple per-feature baseline always keeps a foothold.
  static const double _maxDeepWeight = 0.7;

  DateTime? _lastSampleAt;
  int _sinceFlush = 0;

  // Deep (autoencoder) model state.
  Autoencoder? _deepModel;
  bool _training = false;
  int _sinceTrain = 0;
  int _deepRounds = 0;

  late final ValueNotifier<PersonalizationStatus> _status;
  PersonalizationStage? _lastStage;

  /// Live personalization progress for an optional dashboard card.
  ValueListenable<PersonalizationStatus> get status => _status;

  @override
  Future<void> initializeModel() => _fallback.initializeModel();

  @override
  Future<PredictionResult> runInference(List<double> features) async {
    final pop = await _fallback.runInference(features);

    // 1. Collect + train, but only from calm, on-baseline readings, and no more
    //    than once per [minSampleGap] so the training set stays decorrelated.
    final activity = features.length > 6 ? features[6] : 1.0;
    final isCalm = activity <= _config.calmActivityMax &&
        pop.overallAnomalyProbability <= _config.calmRiskMax;
    final now = DateTime.now();
    final isDue = _lastSampleAt == null ||
        now.difference(_lastSampleAt!) >= _config.minSampleGap;

    if (isCalm && isDue) {
      _lastSampleAt = now;
      _model.observe(features); // O(1) online training (Gaussian baseline)
      unawaited(_store.append(features, now)); // persist the individual's vitals
      if (++_sinceFlush >= _config.flushEverySamples) {
        _sinceFlush = 0;
        unawaited(_store.saveModel(_model.toSnapshot()));
      }
      _sinceTrain++;
      _maybeRetrainDeepModel(); // schedule a background training pass if due
      _emitStatus();
    }

    // 2. Personal anomaly: the diagonal Gaussian baseline, upgraded toward the
    //    deep autoencoder as it comes online. Deep-model trust ramps over its
    //    first few rounds so the signal never jumps when it activates.
    final gaussianAnomaly = _model.score(features);
    var personalAnomaly = gaussianAnomaly;
    final deep = _deepModel;
    if (deep != null && deep.ready) {
      final deepWeight = (_deepRounds / 3.0).clamp(0.0, 1.0) * _maxDeepWeight;
      personalAnomaly = (1.0 - deepWeight) * gaussianAnomaly +
          deepWeight * deep.score(features);
    }

    // 3. Blend population → personal by how much we have learned.
    final conf = _model.confidence(_config.personalizedSamples);
    final blended =
        (1.0 - conf) * pop.overallAnomalyProbability + conf * personalAnomaly;

    // 4. Guardrail: personalization removes false alarms, it never hides danger.
    final anomaly = max(blended, _hardFloor(features)).clamp(0.0, 1.0);

    return PredictionResult(
      heatStressProbability: pop.heatStressProbability,
      dehydrationRiskProbability: pop.dehydrationRiskProbability,
      fatigueProbability: pop.fatigueProbability,
      respiratoryRiskProbability: pop.respiratoryRiskProbability,
      cardiovascularRiskProbability: pop.cardiovascularRiskProbability,
      overallAnomalyProbability: double.parse(anomaly.toStringAsFixed(3)),
      timestamp: pop.timestamp,
      signalsAvailable: pop.signalsAvailable,
      signalsTotal: pop.signalsTotal,
    );
  }

  /// Absolute physiological red lines that always dominate, regardless of what
  /// the personal model has learned. Derived from the frozen feature layout:
  /// f2 = (SpO2 - 70)/30, f4 = (bodyTemp - 34)/8.
  double _hardFloor(List<double> f) {
    var floor = 0.0;
    final spo2Norm = f.length > 2 ? f[2] : 1.0;
    final tempNorm = f.length > 4 ? f[4] : 0.0;
    if (spo2Norm < 0.60) floor = max(floor, 0.85); // SpO2 < 88%
    if (tempNorm > 0.625) floor = max(floor, 0.85); // body temp > 39.0 degC
    return floor;
  }

  PersonalizationStatus _buildStatus() {
    final n = _model.sampleCount;
    final PersonalizationStage stage;
    if (n < _config.stage1Samples) {
      stage = PersonalizationStage.learning;
    } else if (n < _config.personalizedSamples) {
      stage = PersonalizationStage.personalizing;
    } else {
      stage = PersonalizationStage.personalized;
    }
    return PersonalizationStatus(
      stage: stage,
      sampleCount: n,
      target: _config.personalizedSamples,
      confidence: _model.confidence(_config.personalizedSamples),
      deepModelActive: _deepModel?.ready ?? false,
      trainingRounds: _deepRounds,
    );
  }

  void _emitStatus() {
    final next = _buildStatus();
    _status.value = next;
    if (next.stage != _lastStage) {
      _lastStage = next.stage;
      debugPrint(
        '[PRANA personalization] ${next.label} '
        '(${next.sampleCount}/${next.target} samples)',
      );
    }
  }

  /// Resume the deep autoencoder from its persisted snapshot, if one exists.
  /// Runs off the hot path from the constructor; until it lands (or if it never
  /// does) the Gaussian baseline drives personalization.
  Future<void> _loadDeepModel() async {
    try {
      final snap = await _store.loadAutoencoder();
      if (snap != null) {
        final deep = Autoencoder.fromSnapshot(snap);
        _deepModel = deep;
        _deepRounds = deep.trainedRounds;
        _emitStatus();
      }
    } catch (_) {
      // A corrupt deep-model blob just means we retrain from scratch; the
      // Gaussian keeps personalization working in the meantime.
    }
  }

  /// Kick off a background training pass if enough samples have accrued and one
  /// is not already running. Fire-and-forget: the tick never blocks on training.
  void _maybeRetrainDeepModel() {
    if (_training) return;
    if (_model.sampleCount < _config.aeMinSamples) return;
    final firstPass = _deepModel == null;
    if (!firstPass && _sinceTrain < _config.retrainEverySamples) return;
    _training = true;
    _sinceTrain = 0;
    unawaited(_retrainDeepModel());
  }

  /// Train the autoencoder in a background isolate on the recent calm samples,
  /// then install and persist the result. DB reads stay on this isolate; only
  /// plain lists cross into `compute`.
  Future<void> _retrainDeepModel() async {
    try {
      final batch = await _store.recent(_config.aeBatchSize);
      if (batch.length < _config.aeMinSamples) return;
      final deep = _deepModel ?? Autoencoder.initial();
      final result = await compute(
        trainAutoencoderIsolate,
        deep.trainingPayload(
          batch,
          epochs: _config.aeEpochs,
          learningRate: _config.aeLearningRate,
          l2: _config.aeL2,
        ),
      );
      if (result['ok'] == true) {
        deep.loadTrained(result);
        _deepModel = deep;
        _deepRounds = deep.trainedRounds;
        unawaited(_store.saveAutoencoder(deep.toSnapshot()));
        _emitStatus();
        debugPrint(
          '[PRANA personalization] deep model trained '
          '(round $_deepRounds · ${batch.length} samples · '
          'err μ=${deep.errMean.toStringAsFixed(4)})',
        );
      }
    } catch (e) {
      debugPrint('[PRANA personalization] deep-model training skipped: $e');
    } finally {
      _training = false;
    }
  }

  @override
  void dispose() {
    // Best-effort final flush so the last few samples are not lost.
    unawaited(_store.saveModel(_model.toSnapshot()));
    final deep = _deepModel;
    if (deep != null) unawaited(_store.saveAutoencoder(deep.toSnapshot()));
    _fallback.dispose();
    _status.dispose();
  }
}
