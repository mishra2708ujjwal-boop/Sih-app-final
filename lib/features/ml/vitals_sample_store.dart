import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// On-device local database for the ML pipeline (pure-Dart sembast).
///
/// Two stores inside one app-private `.db` file:
///  * `samples` — the individual's calm vitals as 16-feature vectors, a rolling
///    window bounded to [_cap]. This is the raw training reservoir the Phase-2
///    autoencoder will replay; the Phase-1 Gaussian model needs only the
///    running statistics, which live in `meta`.
///  * `meta`    — the learned [PersonalModel] snapshot, so training resumes
///    across app restarts instead of starting over.
///
/// Everything is app-private, offline, and wiped by the privacy reset. All I/O
/// happens on the main isolate — a background training isolate (Phase 2) only
/// ever receives plain lists, never this database (sembast/path_provider use
/// platform channels that are unavailable inside `compute`).
class VitalsSampleStore {
  VitalsSampleStore._(this._db);

  final Database _db;

  static const String _dbFileName = 'prana_ml.db';
  static const String _modelKey = 'personal_model';
  static const String _autoencoderKey = 'autoencoder_model';
  static const int _cap = 2000;

  static final StoreRef<int, Map<String, Object?>> _samples =
      intMapStoreFactory.store('samples');
  static final StoreRef<String, Map<String, Object?>> _meta =
      stringMapStoreFactory.store('meta');

  static Future<String> _dbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return p.join(dir.path, _dbFileName);
  }

  /// Open (or create) the database in app-private storage.
  static Future<VitalsSampleStore> open() async {
    final db = await databaseFactoryIo.openDatabase(await _dbPath());
    return VitalsSampleStore._(db);
  }

  /// Append one calm feature vector, then trim the oldest rows past [_cap].
  Future<void> append(List<double> features, DateTime at) async {
    await _samples.add(_db, {
      't': at.toIso8601String(),
      'f': features,
    });
    final overflow = await _samples.count(_db) - _cap;
    if (overflow > 0) {
      // Records use auto-incrementing int keys, so ascending key order == oldest
      // first: delete the oldest [overflow] rows to keep a rolling window.
      await _samples.delete(
        _db,
        finder: Finder(sortOrders: [SortOrder(Field.key)], limit: overflow),
      );
    }
  }

  Future<int> count() => _samples.count(_db);

  /// Most-recent [n] feature vectors, returned oldest-first (Phase-2 training).
  Future<List<List<double>>> recent(int n) async {
    final records = await _samples.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('t', false)], limit: n),
    );
    final vectors = records
        .map((r) => (r.value['f'] as List)
            .map((e) => (e as num).toDouble())
            .toList())
        .toList();
    return vectors.reversed.toList();
  }

  /// Every stored sample with its capture time, oldest-first. Unlike [recent]
  /// (vectors only, for training), this carries the timestamp for export and
  /// human inspection. Mirrors [recent]'s sort field ('t'); ISO-8601 strings
  /// order chronologically, so ascending == oldest-first.
  Future<List<VitalsSample>> allSamples() async {
    final records = await _samples.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('t')]),
    );
    return [
      for (final r in records)
        VitalsSample(
          at: DateTime.tryParse(r.value['t'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          features: (r.value['f'] as List)
              .map((e) => (e as num).toDouble())
              .toList(),
        ),
    ];
  }

  /// Load the persisted [PersonalModel] snapshot, or null on first run.
  Future<Map<String, Object?>?> loadModel() => _meta.record(_modelKey).get(_db);

  /// Persist the [PersonalModel] snapshot.
  Future<void> saveModel(Map<String, Object?> snapshot) =>
      _meta.record(_modelKey).put(_db, snapshot);

  /// Load the persisted deep autoencoder snapshot, or null if never trained.
  Future<Map<String, Object?>?> loadAutoencoder() =>
      _meta.record(_autoencoderKey).get(_db);

  /// Persist the deep autoencoder snapshot so training resumes across restarts.
  Future<void> saveAutoencoder(Map<String, Object?> snapshot) =>
      _meta.record(_autoencoderKey).put(_db, snapshot);

  Future<void> close() => _db.close();

  /// Privacy wipe: delete the entire on-device ML database file. Static so the
  /// privacy service can call it without holding an open instance.
  static Future<void> deleteDatabaseFile() async {
    await databaseFactoryIo.deleteDatabase(await _dbPath());
  }
}

/// One stored calm reading: its capture time plus the 16-feature vector the
/// model trained on. Returned by [VitalsSampleStore.allSamples] for export and
/// on-screen inspection; the vector decodes to real units via DecodedReading.
class VitalsSample {
  const VitalsSample({required this.at, required this.features});

  final DateTime at;
  final List<double> features;
}
