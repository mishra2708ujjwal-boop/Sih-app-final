import '../../core/database/local_storage_service.dart';
import '../ml/vitals_sample_store.dart';

/// Privacy Controls & Local Edge Data Residency Manager
class PrivacyService {
  final LocalStorageService _storage;
  final Map<String, bool> _settings;

  PrivacyService(this._storage) : _settings = _storage.getPrivacySettings();

  Map<String, bool> get settings => _settings;

  bool get isLocationSharingEnabled => _settings['shareLocation'] ?? true;
  bool get isFamilySharingEnabled => _settings['shareFamily'] ?? false;
  bool get isHealthcareSharingEnabled => _settings['shareHealthcare'] ?? false;
  bool get isEmergencySharingEnabled => _settings['shareEmergency'] ?? true;
  bool get isCloudSyncEnabled => _settings['cloudSync'] ?? false;

  Future<void> updateToggle(String key, bool value) async {
    _settings[key] = value;
    await _storage.savePrivacySettings(_settings);
  }

  Future<void> wipeAllLocalData() async {
    await _storage.clearAllData();
    // Also erase the on-device ML database (the individual's stored vitals and
    // learned baseline model), so the privacy wipe is complete.
    await VitalsSampleStore.deleteDatabaseFile();
  }
}
