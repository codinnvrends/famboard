import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// FamBoard's namespace for deterministic (UUID v5) ids.
const _namespace = '6f1c6a4e-2b8d-4c1a-9d7e-3a5b8c0f2e41';

/// Time-ordered random id for new records (UUID v7).
String newId() => _uuid.v7();

/// Deterministic id: two devices computing it from the same [parts] get the
/// same id, so their records merge instead of duplicating.
String stableId(List<String> parts) =>
    _uuid.v5(_namespace, parts.join('\u001f'));

/// Random hex string, used for device ids.
String randomHex(int bytes) {
  final rnd = Random.secure();
  return List.generate(
    bytes,
    (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
