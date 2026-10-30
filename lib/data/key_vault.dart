import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secrets kept in the platform keystore (Android Keystore / iOS Keychain):
/// the database key and one 32-byte key per family.
abstract class KeyVault {
  Future<String> databaseKey();
  Future<Uint8List?> familyKey(String familyId);
  Future<void> saveFamilyKey(String familyId, Uint8List key);
  Future<void> deleteFamilyKey(String familyId);
  Future<Map<String, Uint8List>> allFamilyKeys();

  static Uint8List randomKey() {
    final rnd = Random.secure();
    return Uint8List.fromList(List.generate(32, (_) => rnd.nextInt(256)));
  }
}

class SecureKeyVault implements KeyVault {
  SecureKeyVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _dbKey = 'famboard.dbkey';
  static const _familyPrefix = 'famboard.family.';

  @override
  Future<String> databaseKey() async {
    final existing = await _storage.read(key: _dbKey);
    if (existing != null) return existing;
    final key = KeyVault.randomKey()
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _dbKey, value: key);
    return key;
  }

  @override
  Future<Uint8List?> familyKey(String familyId) async {
    final v = await _storage.read(key: '$_familyPrefix$familyId');
    return v == null ? null : base64Decode(v);
  }

  @override
  Future<void> saveFamilyKey(String familyId, Uint8List key) =>
      _storage.write(key: '$_familyPrefix$familyId', value: base64Encode(key));

  @override
  Future<void> deleteFamilyKey(String familyId) =>
      _storage.delete(key: '$_familyPrefix$familyId');

  @override
  Future<Map<String, Uint8List>> allFamilyKeys() async {
    final all = await _storage.readAll();
    return {
      for (final e in all.entries)
        if (e.key.startsWith(_familyPrefix))
          e.key.substring(_familyPrefix.length): base64Decode(e.value),
    };
  }
}

/// In-memory vault for tests.
class MemoryKeyVault implements KeyVault {
  final Map<String, Uint8List> keys = {};

  @override
  Future<String> databaseKey() async => '00' * 32;

  @override
  Future<Uint8List?> familyKey(String familyId) async => keys[familyId];

  @override
  Future<void> saveFamilyKey(String familyId, Uint8List key) async =>
      keys[familyId] = key;

  @override
  Future<void> deleteFamilyKey(String familyId) async => keys.remove(familyId);

  @override
  Future<Map<String, Uint8List>> allFamilyKeys() async => Map.of(keys);
}
