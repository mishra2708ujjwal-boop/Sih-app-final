import 'dart:math';

/// Per-person baseline model, learned on-device with zero labels.
///
/// This is the "trained per person" part of the pipeline. It keeps online
/// mean/variance for each of the 16 frozen features (Welford's algorithm), so
/// it is trained continuously — one O(1) update per accepted reading, no batch
/// step, no dataset, no network. Anomaly is the diagonal Mahalanobis distance
/// of a new reading from *this person's* learned normal, squashed to [0, 1).
///
/// It is deliberately written against a tiny surface (`observe` / `score` /
/// snapshot) so the Phase-2 autoencoder can implement the same contract and
/// drop in behind [PersonalizedInferenceService] without touching callers.
class PersonalModel {
  /// Length of the frozen feature vector (see FeatureProcessor v1.1.0).
  static const int dims = 16;

  int _n;
  final List<double> _mean; // running mean per feature
  final List<double> _m2; // running sum of squared deviations (Welford)
  DateTime _updatedAt;

  PersonalModel._(this._n, this._mean, this._m2, this._updatedAt);

  /// A brand-new model with no learned data (cold start).
  factory PersonalModel.fresh() => PersonalModel._(
        0,
        List<double>.filled(dims, 0.0),
        List<double>.filled(dims, 0.0),
        DateTime.now(),
      );

  int get sampleCount => _n;
  DateTime get updatedAt => _updatedAt;

  /// Blend weight for the personal model vs. the population prior, in [0, 1].
  double confidence(int target) =>
      target <= 0 ? 1.0 : (_n / target).clamp(0.0, 1.0);

  /// Fold one feature vector into the running statistics. This is the training.
  void observe(List<double> x) {
    if (x.length < dims) return;
    _n++;
    for (var i = 0; i < dims; i++) {
      final delta = x[i] - _mean[i];
      _mean[i] += delta / _n;
      _m2[i] += delta * (x[i] - _mean[i]);
    }
    _updatedAt = DateTime.now();
  }

  double _variance(int i) => _n > 1 ? _m2[i] / (_n - 1) : 1.0;

  /// Personal anomaly in [0, 1): how far [x] sits from this person's own normal,
  /// measured in their own per-feature standard deviations (diagonal
  /// Mahalanobis distance) and squashed. ~0 at rest for a well-learned model,
  /// rising as the reading deviates from the individual's baseline.
  double score(List<double> x) {
    if (_n < 2 || x.length < dims) return 0.0;
    var d2 = 0.0;
    for (var i = 0; i < dims; i++) {
      final sd = sqrt(_variance(i)) + 1e-6;
      final z = (x[i] - _mean[i]) / sd;
      d2 += z * z;
    }
    // Chi-square-like squash: 0 → 0, grows toward 1 as total deviation grows.
    return 1.0 - exp(-d2 / (2.0 * dims));
  }

  /// Compact, JSON-friendly snapshot for persistence (sembast `meta` record).
  Map<String, Object?> toSnapshot() => {
        'v': 1,
        'n': _n,
        'mean': _mean,
        'm2': _m2,
        'updatedAt': _updatedAt.toIso8601String(),
      };

  /// Rehydrate from a persisted snapshot. Falls back to [PersonalModel.fresh]
  /// if the blob is malformed or from an incompatible layout, so a corrupt
  /// record can never crash startup.
  factory PersonalModel.fromSnapshot(Map<String, Object?> s) {
    List<double>? readVec(Object? o) {
      if (o is! List || o.length != dims) return null;
      return o.map((e) => (e as num).toDouble()).toList();
    }

    final mean = readVec(s['mean']);
    final m2 = readVec(s['m2']);
    final n = (s['n'] as num?)?.toInt();
    if (mean == null || m2 == null || n == null || n < 0) {
      return PersonalModel.fresh();
    }
    final updated = DateTime.tryParse(s['updatedAt'] as String? ?? '');
    return PersonalModel._(n, mean, m2, updated ?? DateTime.now());
  }
}
