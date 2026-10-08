import 'dart:math';

/// Tiny denoising-free autoencoder — the Phase-2 "deep" personal model.
///
/// Architecture: 16 → 8 → 4 → 8 → 16 (tanh hidden layers, linear output),
/// ~356 weights. It learns the *manifold* of this person's calm vitals, so it
/// captures cross-feature correlations the diagonal Gaussian ([PersonalModel])
/// cannot — e.g. "for me, HR 95 is normal only when SpO2 and temp are also up."
/// A reading that does not lie on that learned manifold reconstructs poorly, and
/// that reconstruction error is the anomaly signal.
///
/// It implements the same tiny surface as [PersonalModel] (`score` + snapshot)
/// so [PersonalizedInferenceService] can blend it in without callers noticing.
///
/// Everything here is framework-free (only `dart:math`) on purpose: the training
/// pass runs in a background isolate via `compute`, and platform channels are
/// unavailable there. The isolate only ever receives/returns plain lists.
class Autoencoder {
  static const int nIn = 16;
  static const int nH1 = 8;
  static const int nZ = 4; // bottleneck
  static const int nH2 = 8;
  static const int nOut = 16;

  List<List<double>> w1; // nH1 x nIn
  List<double> b1;
  List<List<double>> w2; // nZ x nH1
  List<double> b2;
  List<List<double>> w3; // nH2 x nZ
  List<double> b3;
  List<List<double>> w4; // nOut x nH2
  List<double> b4;

  /// Mean and std of the reconstruction error over the last training batch —
  /// the reference scale that turns a raw error into a [0, 1) anomaly.
  double errMean;
  double errStd;

  /// Completed background training passes.
  int trainedRounds;

  /// Samples in the last training batch.
  int trainedOn;

  /// True once at least one training pass has completed; until then the model
  /// is random and [score] returns 0 so the Gaussian stays in charge.
  bool ready;

  Autoencoder._(
    this.w1,
    this.b1,
    this.w2,
    this.b2,
    this.w3,
    this.b3,
    this.w4,
    this.b4, {
    required this.errMean,
    required this.errStd,
    required this.trainedRounds,
    required this.trainedOn,
    required this.ready,
  });

  /// Fresh, randomly initialised model (Xavier-uniform), not yet trained.
  factory Autoencoder.initial({int seed = 42}) {
    final r = Random(seed);
    List<List<double>> mat(int rows, int cols) {
      final limit = sqrt(6.0 / (rows + cols));
      return List.generate(
        rows,
        (_) => List.generate(cols, (_) => (r.nextDouble() * 2 - 1) * limit),
      );
    }

    return Autoencoder._(
      mat(nH1, nIn),
      List<double>.filled(nH1, 0.0),
      mat(nZ, nH1),
      List<double>.filled(nZ, 0.0),
      mat(nH2, nZ),
      List<double>.filled(nH2, 0.0),
      mat(nOut, nH2),
      List<double>.filled(nOut, 0.0),
      errMean: 0.0,
      errStd: 1.0,
      trainedRounds: 0,
      trainedOn: 0,
      ready: false,
    );
  }

  /// Mean-squared reconstruction error of [x] under the current weights.
  double reconstructionError(List<double> x) {
    final h1 = _dense(w1, b1, x, tanhAct: true);
    final z = _dense(w2, b2, h1, tanhAct: true);
    final h3 = _dense(w3, b3, z, tanhAct: true);
    final y = _dense(w4, b4, h3, tanhAct: false);
    var s = 0.0;
    for (var i = 0; i < nOut; i++) {
      final d = y[i] - x[i];
      s += d * d;
    }
    return s / nOut;
  }

  /// Personal anomaly in [0, 1): 0 when the reading reconstructs about as well
  /// as the person's held-out calm data, rising as it deviates from that
  /// manifold. Returns 0 until the first training pass lands.
  ///
  /// The scale [errMean]/[errStd] is measured on samples the model never trained
  /// on, so a *fresh* calm reading sits near [errMean] and scores ~0. The band
  /// is floored relative to [errMean] so a very tight std cannot make ordinary
  /// readings look anomalous.
  double score(List<double> x) {
    if (!ready || x.length < nIn) return 0.0;
    final band = max(errStd, 0.25 * errMean) + 1e-9;
    final excess = reconstructionError(x) - (errMean + 2.0 * band);
    if (excess <= 0) return 0.0;
    return 1.0 - exp(-excess / band);
  }

  /// Build the plain-list payload for the background trainer ([trainAutoencoderIsolate]).
  Map<String, Object?> trainingPayload(
    List<List<double>> samples, {
    required int epochs,
    required double learningRate,
    required double l2,
  }) =>
      {
        'w1': w1,
        'b1': b1,
        'w2': w2,
        'b2': b2,
        'w3': w3,
        'b3': b3,
        'w4': w4,
        'b4': b4,
        'samples': samples,
        'epochs': epochs,
        'lr': learningRate,
        'l2': l2,
      };

  /// Install the weights + error stats returned by [trainAutoencoderIsolate].
  void loadTrained(Map<String, Object?> r) {
    w1 = _mat(r['w1']);
    b1 = _vec(r['b1']);
    w2 = _mat(r['w2']);
    b2 = _vec(r['b2']);
    w3 = _mat(r['w3']);
    b3 = _vec(r['b3']);
    w4 = _mat(r['w4']);
    b4 = _vec(r['b4']);
    errMean = (r['errMean'] as num).toDouble();
    errStd = (r['errStd'] as num).toDouble();
    trainedOn = (r['trainedOn'] as num?)?.toInt() ?? trainedOn;
    trainedRounds += 1;
    ready = true;
  }

  /// JSON-friendly snapshot for persistence (sembast `meta` record).
  Map<String, Object?> toSnapshot() => {
        'v': 1,
        'w1': w1,
        'b1': b1,
        'w2': w2,
        'b2': b2,
        'w3': w3,
        'b3': b3,
        'w4': w4,
        'b4': b4,
        'errMean': errMean,
        'errStd': errStd,
        'rounds': trainedRounds,
        'trainedOn': trainedOn,
        'ready': ready,
      };

  /// Rehydrate a snapshot. Any shape mismatch or corruption falls back to a
  /// fresh model, so a bad blob can never crash startup or poison scoring.
  factory Autoencoder.fromSnapshot(Map<String, Object?> s) {
    try {
      List<List<double>> mat(Object? o, int rows, int cols) {
        final m = _mat(o);
        if (m.length != rows || m.any((row) => row.length != cols)) {
          throw StateError('shape');
        }
        return m;
      }

      List<double> vec(Object? o, int n) {
        final v = _vec(o);
        if (v.length != n) throw StateError('len');
        return v;
      }

      return Autoencoder._(
        mat(s['w1'], nH1, nIn),
        vec(s['b1'], nH1),
        mat(s['w2'], nZ, nH1),
        vec(s['b2'], nZ),
        mat(s['w3'], nH2, nZ),
        vec(s['b3'], nH2),
        mat(s['w4'], nOut, nH2),
        vec(s['b4'], nOut),
        errMean: (s['errMean'] as num?)?.toDouble() ?? 0.0,
        errStd: (s['errStd'] as num?)?.toDouble() ?? 1.0,
        trainedRounds: (s['rounds'] as num?)?.toInt() ?? 0,
        trainedOn: (s['trainedOn'] as num?)?.toInt() ?? 0,
        ready: s['ready'] == true,
      );
    } catch (_) {
      return Autoencoder.initial();
    }
  }
}

/// Background training entry point (runs inside `compute`).
///
/// Takes the current weights + a batch of calm feature vectors, runs a few
/// epochs of per-sample SGD with L2 weight decay, and returns the updated
/// weights plus the reconstruction-error scale. Pure lists in, pure lists out —
/// safe to hop the isolate boundary. On divergence (non-finite weights) or bad
/// input it returns `{'ok': false}` and the caller keeps the previous model.
Map<String, Object?> trainAutoencoderIsolate(Map<String, Object?> payload) {
  try {
    final w1 = _mat(payload['w1']);
    final b1 = _vec(payload['b1']);
    final w2 = _mat(payload['w2']);
    final b2 = _vec(payload['b2']);
    final w3 = _mat(payload['w3']);
    final b3 = _vec(payload['b3']);
    final w4 = _mat(payload['w4']);
    final b4 = _vec(payload['b4']);
    final samples = _mat(payload['samples'])
        .where((row) => row.length >= Autoencoder.nIn)
        .toList();
    final epochs = (payload['epochs'] as num).toInt();
    final lr = (payload['lr'] as num).toDouble();
    final l2 = (payload['l2'] as num).toDouble();

    final n = samples.length;
    if (n == 0) return {'ok': false};

    // Hold out a slice for the error scale so it reflects *generalization*
    // error, not the batch the net memorised — otherwise fresh calm readings
    // would look anomalous. Reshuffled each round, so no sample is wasted.
    final rnd = Random(1234);
    final order = List<int>.generate(n, (i) => i);
    order.shuffle(rnd);
    final valCount = n >= 40 ? (n * 0.2).round() : 0;
    final valIdx = order.take(valCount).toSet();
    final trainIdx = [
      for (final i in order)
        if (!valIdx.contains(i)) i
    ];

    for (var e = 0; e < epochs; e++) {
      trainIdx.shuffle(rnd);
      for (final s in trainIdx) {
        _sgdStep(samples[s], w1, b1, w2, b2, w3, b3, w4, b4, lr, l2);
      }
    }

    if (!_allFinite(w1) ||
        !_allFinite([b1]) ||
        !_allFinite(w2) ||
        !_allFinite([b2]) ||
        !_allFinite(w3) ||
        !_allFinite([b3]) ||
        !_allFinite(w4) ||
        !_allFinite([b4])) {
      return {'ok': false};
    }

    // Reconstruction-error scale over the held-out slice (all samples if the
    // batch was too small to split).
    final statIdx = valCount > 0 ? valIdx.toList() : order;
    var sum = 0.0;
    var sumSq = 0.0;
    for (final i in statIdx) {
      final err = _reconError(samples[i], w1, b1, w2, b2, w3, b3, w4, b4);
      sum += err;
      sumSq += err * err;
    }
    final m = statIdx.length;
    final mean = sum / m;
    final variance = (sumSq / m - mean * mean).clamp(0.0, double.infinity);

    return {
      'ok': true,
      'w1': w1,
      'b1': b1,
      'w2': w2,
      'b2': b2,
      'w3': w3,
      'b3': b3,
      'w4': w4,
      'b4': b4,
      'errMean': mean,
      'errStd': sqrt(variance),
      'trainedOn': n,
    };
  } catch (e) {
    return {'ok': false, 'error': e.toString()};
  }
}

// --- shared math (used on both isolates) ------------------------------------

double _tanh(double x) {
  final e = exp(2 * x);
  if (e.isInfinite) return 1.0;
  return (e - 1) / (e + 1);
}

/// One dense layer: activation(W·x + b). Linear when [tanhAct] is false.
List<double> _dense(
  List<List<double>> w,
  List<double> b,
  List<double> x, {
  required bool tanhAct,
}) {
  final out = List<double>.filled(w.length, 0.0);
  for (var i = 0; i < w.length; i++) {
    final row = w[i];
    var s = b[i];
    for (var j = 0; j < row.length; j++) {
      s += row[j] * x[j];
    }
    out[i] = tanhAct ? _tanh(s) : s;
  }
  return out;
}

/// One stochastic-gradient step on a single sample, updating weights in place.
/// Loss is 0.5·Σ(y-x)² (the ½ folds the 2 into the learning rate); L2 decay is
/// applied per weight. Each inner loop reads the weight before overwriting it,
/// so upstream gradients use the pre-update values.
void _sgdStep(
  List<double> x,
  List<List<double>> w1,
  List<double> b1,
  List<List<double>> w2,
  List<double> b2,
  List<List<double>> w3,
  List<double> b3,
  List<List<double>> w4,
  List<double> b4,
  double lr,
  double l2,
) {
  // forward
  final h1 = _dense(w1, b1, x, tanhAct: true);
  final z = _dense(w2, b2, h1, tanhAct: true);
  final h3 = _dense(w3, b3, z, tanhAct: true);
  final y = _dense(w4, b4, h3, tanhAct: false);

  // output layer (linear): dL/dy = y - x
  final dh3 = List<double>.filled(Autoencoder.nH2, 0.0);
  for (var i = 0; i < Autoencoder.nOut; i++) {
    final g = y[i] - x[i];
    final row = w4[i];
    for (var j = 0; j < Autoencoder.nH2; j++) {
      dh3[j] += g * row[j];
      row[j] -= lr * (g * h3[j] + l2 * row[j]);
    }
    b4[i] -= lr * g;
  }

  // hidden layer 3 (tanh)
  final dz = List<double>.filled(Autoencoder.nZ, 0.0);
  for (var i = 0; i < Autoencoder.nH2; i++) {
    final g = dh3[i] * (1 - h3[i] * h3[i]);
    final row = w3[i];
    for (var j = 0; j < Autoencoder.nZ; j++) {
      dz[j] += g * row[j];
      row[j] -= lr * (g * z[j] + l2 * row[j]);
    }
    b3[i] -= lr * g;
  }

  // bottleneck (tanh)
  final dh1 = List<double>.filled(Autoencoder.nH1, 0.0);
  for (var i = 0; i < Autoencoder.nZ; i++) {
    final g = dz[i] * (1 - z[i] * z[i]);
    final row = w2[i];
    for (var j = 0; j < Autoencoder.nH1; j++) {
      dh1[j] += g * row[j];
      row[j] -= lr * (g * h1[j] + l2 * row[j]);
    }
    b2[i] -= lr * g;
  }

  // hidden layer 1 (tanh)
  for (var i = 0; i < Autoencoder.nH1; i++) {
    final g = dh1[i] * (1 - h1[i] * h1[i]);
    final row = w1[i];
    for (var j = 0; j < Autoencoder.nIn; j++) {
      row[j] -= lr * (g * x[j] + l2 * row[j]);
    }
    b1[i] -= lr * g;
  }
}

double _reconError(
  List<double> x,
  List<List<double>> w1,
  List<double> b1,
  List<List<double>> w2,
  List<double> b2,
  List<List<double>> w3,
  List<double> b3,
  List<List<double>> w4,
  List<double> b4,
) {
  final h1 = _dense(w1, b1, x, tanhAct: true);
  final z = _dense(w2, b2, h1, tanhAct: true);
  final h3 = _dense(w3, b3, z, tanhAct: true);
  final y = _dense(w4, b4, h3, tanhAct: false);
  var s = 0.0;
  for (var i = 0; i < Autoencoder.nOut; i++) {
    final d = y[i] - x[i];
    s += d * d;
  }
  return s / Autoencoder.nOut;
}

bool _allFinite(List<List<double>> m) {
  for (final row in m) {
    for (final v in row) {
      if (!v.isFinite) return false;
    }
  }
  return true;
}

List<double> _vec(Object? o) =>
    (o as List).map((e) => (e as num).toDouble()).toList();

List<List<double>> _mat(Object? o) =>
    (o as List).map(_vec).toList();
