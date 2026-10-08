/// Public state of the on-device personalization pipeline.
///
/// Exposed by [PersonalizedInferenceService] as a `ValueListenable` so a small
/// dashboard card (Phase 3) can render "Learning your baseline… 30/50" and flip
/// to "Personalized" live — without the controller having to know any of this.
library;

/// Where the personal model is in its cold-start → personalized journey.
enum PersonalizationStage {
  /// Not enough of the user's own data yet — the population prior is doing
  /// essentially all the work (today's behaviour).
  learning,

  /// The personal baseline is forming and is being blended in with growing
  /// weight as more of the user's readings arrive.
  personalizing,

  /// Enough personal data collected — the model now speaks mostly for *this*
  /// person rather than the population average.
  personalized,
}

/// Immutable snapshot of how far personalization has progressed.
class PersonalizationStatus {
  final PersonalizationStage stage;

  /// How many calm, on-baseline readings the model has learned from.
  final int sampleCount;

  /// Sample count at which the model is considered fully personalized.
  final int target;

  /// 0.0 → 1.0 blend weight given to the personal model vs. the population prior.
  final double confidence;

  /// True once the deep autoencoder has completed at least one training pass and
  /// is contributing to the personal anomaly signal.
  final bool deepModelActive;

  /// Completed background training passes of the deep autoencoder.
  final int trainingRounds;

  const PersonalizationStatus({
    required this.stage,
    required this.sampleCount,
    required this.target,
    required this.confidence,
    this.deepModelActive = false,
    this.trainingRounds = 0,
  });

  /// Human-readable label for a status chip.
  String get label {
    switch (stage) {
      case PersonalizationStage.learning:
        return 'Learning your baseline';
      case PersonalizationStage.personalizing:
        return 'Personalizing';
      case PersonalizationStage.personalized:
        return 'Personalized';
    }
  }
}

/// Tunables for the personalization pipeline. Two presets:
///
/// * [PersonalizationConfig.demo] — collects on every tick and personalizes in
///   ~1 minute so it is visible on stage.
/// * [PersonalizationConfig.production] — downsamples to decorrelated samples
///   and personalizes over hours of real wear.
class PersonalizationConfig {
  /// Sample count at which the model leaves [PersonalizationStage.learning].
  final int stage1Samples;

  /// Sample count at which the model is considered fully personalized. Also the
  /// denominator for the population→personal blend weight.
  final int personalizedSamples;

  /// Minimum wall-clock gap between two stored samples (downsampling). Keeps the
  /// training set decorrelated and the database small.
  final Duration minSampleGap;

  /// Upper bound on the activity feature (index 6) for a sample to count as
  /// "calm" enough to define the baseline. Rest/Low/Moderate pass; vigorous
  /// activity is excluded so exercise HR never becomes "normal".
  final double calmActivityMax;

  /// Upper bound on the population model's overall-anomaly probability for a
  /// sample to be admitted. This is the reliable gate: it keeps disaster-state
  /// readings out of the learned "normal".
  final double calmRiskMax;

  /// Persist the learned model to disk every N accepted samples.
  final int flushEverySamples;

  /// Maximum retained raw samples (rolling window).
  final int sampleCap;

  /// Minimum learned samples before the deep autoencoder starts training. Set
  /// above [stage1Samples] so the quick Gaussian baseline shows first.
  final int aeMinSamples;

  /// Retrain the deep autoencoder every N further accepted samples.
  final int retrainEverySamples;

  /// How many recent samples each background training pass replays.
  final int aeBatchSize;

  /// SGD epochs per training pass.
  final int aeEpochs;

  /// SGD learning rate.
  final double aeLearningRate;

  /// L2 weight-decay coefficient (guards the tiny net against overfitting the
  /// small, correlated sample reservoir).
  final double aeL2;

  const PersonalizationConfig({
    required this.stage1Samples,
    required this.personalizedSamples,
    required this.minSampleGap,
    required this.calmActivityMax,
    required this.calmRiskMax,
    required this.flushEverySamples,
    required this.sampleCap,
    required this.aeMinSamples,
    required this.retrainEverySamples,
    required this.aeBatchSize,
    required this.aeEpochs,
    required this.aeLearningRate,
    required this.aeL2,
  });

  /// Stage-friendly: fills up fast so judges can watch it personalize.
  const PersonalizationConfig.demo()
      : stage1Samples = 30,
        personalizedSamples = 150,
        minSampleGap = Duration.zero,
        calmActivityMax = 0.6,
        calmRiskMax = 0.4,
        flushEverySamples = 10,
        sampleCap = 2000,
        aeMinSamples = 60,
        retrainEverySamples = 20,
        aeBatchSize = 300,
        aeEpochs = 40,
        aeLearningRate = 0.03,
        aeL2 = 1e-4;

  /// Realistic: decorrelated samples over hours of wear.
  const PersonalizationConfig.production()
      : stage1Samples = 50,
        personalizedSamples = 500,
        minSampleGap = const Duration(seconds: 30),
        calmActivityMax = 0.6,
        calmRiskMax = 0.4,
        flushEverySamples = 20,
        sampleCap = 2000,
        aeMinSamples = 120,
        retrainEverySamples = 100,
        aeBatchSize = 1000,
        aeEpochs = 60,
        aeLearningRate = 0.02,
        aeL2 = 1e-4;
}
