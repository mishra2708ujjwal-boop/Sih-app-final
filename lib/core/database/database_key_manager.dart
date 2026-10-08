import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Generates and stores the SQLCipher database passphrase in the platform
/// Keychain/Keystore via flutter_secure_storage -- never in SharedPreferences,
/// never in plain source, per the project's encryption-key rule.
class DatabaseKeyManager {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'prana_db_encryption_key';

  /// Returns the existing key, or generates and persists a new
  /// cryptographically random 256-bit key on first run.
  static Future<String> getOrCreateKey() async {
    final existing = await _storage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final hexKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

    await _storage.write(key: _keyName, value: hexKey);
    return hexKey;
  }
}
