import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:intl/intl.dart';

import '../data/famboard_repository.dart';
import '../data/key_vault.dart';
import '../data/record_store.dart';
import '../data/settings_store.dart';
import '../domain/categories.dart';
import '../domain/change.dart';
import '../domain/models.dart';

class BackupException implements Exception {
  BackupException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Data export (CSV, JSON) and passphrase-encrypted backups (spec FR-60,
/// FR-61). A backup holds the family key and the full change log, so it can
/// restore a family on a new phone and then keep syncing.
class BackupService {
  BackupService({
    required this.store,
    required this.repo,
    required this.settings,
    required this.vault,
  });

  final RecordStore store;
  final FamBoardRepository repo;
  final SettingsStore settings;
  final KeyVault vault;

  static const _magic = 'FAMBOARD-BACKUP-1';
  static const _iterations = 150000;

  // Export -------------------------------------------------------------------

  Future<String> exportCsv(String familyId) async {
    final entries = await repo.entries(familyId);
    final members = {for (final m in await repo.members(familyId)) m.id: m.name};
    final date = DateFormat('yyyy-MM-dd');
    final rows = <List<String>>[
      ['Title', 'Type', 'Category', 'Priority', 'Status', 'Quantity', 'Unit', 'Amount',
        'Due', 'Assignee', 'Repeats', 'Note', 'Created by', 'Updated'],
      for (final e in entries)
        [
          e.title,
          e.type.code,
          categoryById(e.categoryId).en,
          e.priority.code,
          e.status.code,
          e.quantity?.toString() ?? '',
          e.unit ?? '',
          e.amount?.toStringAsFixed(2) ?? '',
          e.dueAt == null ? '' : date.format(e.dueAt!),
          members[e.assigneeId] ?? '',
          e.rrule ?? '',
          e.note ?? '',
          members[e.createdBy] ?? '',
          date.format(e.updatedAt),
        ],
    ];
    return rows.map((r) => r.map(_csvCell).join(',')).join('\r\n');
  }

  Future<String> exportJson(String familyId) async {
    final entries = await store.list(familyId, Entities.entry);
    final members = await store.list(familyId, Entities.member);
    final family = await store.list(familyId, Entities.family);
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'FamBoard',
      'exportedAt': DateTime.now().toIso8601String(),
      'family': family.map((r) => {'id': r.id, ...r.fields}).firstOrNull,
      'members': members.map((r) => {'id': r.id, ...r.fields}).toList(),
      'entries': entries.map((r) => {'id': r.id, ...r.fields}).toList(),
    });
  }

  static String _csvCell(String v) {
    final needsQuotes = v.contains(',') || v.contains('"') || v.contains('\n');
    final escaped = v.replaceAll('"', '""');
    return needsQuotes ? '"$escaped"' : escaped;
  }

  // Encrypted backup -----------------------------------------------------------

  Future<Uint8List> createBackup(String familyId, String passphrase) async {
    if (passphrase.length < 6) {
      throw BackupException('Use a passphrase of at least 6 characters.');
    }
    final key = await vault.familyKey(familyId);
    final local = (await settings.families()).where((f) => f.id == familyId).firstOrNull;
    if (key == null || local == null) throw BackupException('Family not found on this phone.');
    final changes = await store.allChanges(familyId);
    final payload = utf8.encode(jsonEncode({
      'family': local.toJson(),
      'key': base64Encode(key),
      'changes': changes.map((c) => c.toWire()).toList(),
    }));

    final salt = _random(16);
    final secret = await _deriveKey(passphrase, salt);
    final box = await AesGcm.with256bits().encrypt(payload, secretKey: secret);
    final header = utf8.encode(jsonEncode({
      'magic': _magic,
      'kdf': 'pbkdf2-sha256',
      'iter': _iterations,
      'salt': base64Encode(salt),
      'nonce': base64Encode(box.nonce),
      'mac': base64Encode(box.mac.bytes),
    }));
    final out = BytesBuilder()
      ..add(_u32(header.length))
      ..add(header)
      ..add(box.cipherText);
    return out.takeBytes();
  }

  /// Restores a backup and makes its family active. Returns the family.
  Future<LocalFamily> restoreBackup(Uint8List bytes, String passphrase) async {
    if (bytes.length < 8) throw BackupException('This is not a FamBoard backup.');
    final headerLen = ByteData.view(bytes.buffer, bytes.offsetInBytes, 4).getUint32(0);
    if (headerLen > 4096 || bytes.length < 4 + headerLen) {
      throw BackupException('This is not a FamBoard backup.');
    }
    final Map<String, Object?> header;
    try {
      header = jsonDecode(utf8.decode(bytes.sublist(4, 4 + headerLen))) as Map<String, Object?>;
    } catch (_) {
      throw BackupException('This is not a FamBoard backup.');
    }
    if (header['magic'] != _magic) throw BackupException('This is not a FamBoard backup.');
    final secret = await _deriveKey(
      passphrase,
      base64Decode(header['salt']! as String),
      iterations: (header['iter']! as num).toInt(),
    );
    final List<int> clear;
    try {
      clear = await AesGcm.with256bits().decrypt(
        SecretBox(
          bytes.sublist(4 + headerLen),
          nonce: base64Decode(header['nonce']! as String),
          mac: Mac(base64Decode(header['mac']! as String)),
        ),
        secretKey: secret,
      );
    } on SecretBoxAuthenticationError {
      throw BackupException('Wrong passphrase.');
    }
    final payload = jsonDecode(utf8.decode(clear)) as Map<String, Object?>;
    final family = LocalFamily.fromJson(Map<String, Object?>.from(payload['family']! as Map));
    await vault.saveFamilyKey(family.id, base64Decode(payload['key']! as String));
    final changes = (payload['changes']! as List)
        .map((e) => Change.fromWire(Map<String, Object?>.from(e! as Map)))
        .toList();
    for (var i = 0; i < changes.length; i += 1000) {
      await store.applyRemote(changes.sublist(i, min(i + 1000, changes.length)));
    }
    await settings.upsertFamily(family);
    await settings.set(SettingsStore.kActiveFamily, family.id);
    return family;
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt, {
    int iterations = _iterations,
  }) =>
      Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: iterations, bits: 256)
          .deriveKeyFromPassword(password: passphrase, nonce: salt);

  static Uint8List _random(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  static Uint8List _u32(int v) {
    final b = Uint8List(4);
    ByteData.view(b.buffer).setUint32(0, v);
    return b;
  }
}
