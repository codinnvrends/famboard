import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';

import '../domain/models.dart';
import 'db/database.dart';
import 'record_store.dart';

/// What sync needs to swap photos with a peer.
abstract class BlobSource {
  /// Photo ids that records in [familyId] point at but this phone lacks.
  Future<List<String>> missingBlobs(String familyId);

  Future<Uint8List?> blob(String familyId, String id);

  /// Stores [bytes] if they hash to [id]; returns false (and drops them)
  /// otherwise, so a peer can't plant a different photo under a known id.
  Future<bool> putVerified(String familyId, String id, Uint8List bytes, {String mime});
}

/// Photos kept in the encrypted database, addressed by SHA-256, so the same
/// photo is stored once and every phone agrees on its id.
class BlobStore implements BlobSource {
  BlobStore(this.db, this.store);

  final AppDatabase db;
  final RecordStore store;

  /// Fields that hold lists of photo ids, per entity.
  static const _photoFields = {Entities.appliance: 'photos'};

  final _added = StreamController<String>.broadcast();

  /// Emits a photo id whenever one is stored (taken here or synced in).
  Stream<String> get added => _added.stream;

  static Future<String> hashOf(List<int> bytes) async {
    final digest = await Sha256().hash(bytes);
    final b = StringBuffer();
    for (final x in digest.bytes) {
      b.write(x.toRadixString(16).padLeft(2, '0'));
    }
    return b.toString();
  }

  /// Stores a photo taken on this phone and returns its id.
  Future<String> put(String familyId, Uint8List bytes, {String mime = 'image/jpeg'}) async {
    final id = await hashOf(bytes);
    await _insert(familyId, id, bytes, mime);
    return id;
  }

  @override
  Future<bool> putVerified(String familyId, String id, Uint8List bytes, {String mime = 'image/jpeg'}) async {
    if (await hashOf(bytes) != id) return false;
    await _insert(familyId, id, bytes, mime);
    return true;
  }

  Future<void> _insert(String familyId, String id, Uint8List bytes, String mime) async {
    await db.into(db.blobs).insert(
          BlobsCompanion.insert(
            familyId: familyId,
            id: id,
            mime: mime,
            bytes: bytes,
            created: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
    _added.add(id);
  }

  @override
  Future<Uint8List?> blob(String familyId, String id) async {
    final row = await (db.select(db.blobs)
          ..where((b) => b.familyId.equals(familyId) & b.id.equals(id)))
        .getSingleOrNull();
    return row?.bytes;
  }

  Future<bool> has(String familyId, String id) async {
    final row = await (db.selectOnly(db.blobs)
          ..addColumns([db.blobs.id])
          ..where(db.blobs.familyId.equals(familyId) & db.blobs.id.equals(id)))
        .getSingleOrNull();
    return row != null;
  }

  /// Every photo id that a live record in [familyId] points at.
  Future<Set<String>> referenced(String familyId) async {
    final ids = <String>{};
    for (final e in _photoFields.entries) {
      for (final r in await store.list(familyId, e.key)) {
        final list = r.fields[e.value];
        if (list is List) ids.addAll(list.whereType<String>());
      }
    }
    return ids;
  }

  Future<Set<String>> _present(String familyId) async {
    final rows = await (db.selectOnly(db.blobs)
          ..addColumns([db.blobs.id])
          ..where(db.blobs.familyId.equals(familyId)))
        .get();
    return rows.map((r) => r.read(db.blobs.id)!).toSet();
  }

  @override
  Future<List<String>> missingBlobs(String familyId) async {
    final have = await _present(familyId);
    return (await referenced(familyId)).difference(have).toList()..sort();
  }

  /// Every stored photo of a family (backups).
  Future<Map<String, Uint8List>> all(String familyId) async {
    final rows = await (db.select(db.blobs)..where((b) => b.familyId.equals(familyId))).get();
    return {for (final r in rows) r.id: r.bytes};
  }

  /// Drops photos nothing points at any more (after deletes), keeping ones
  /// stored in the last day in case the record that uses them is still
  /// being written or synced.
  Future<int> sweep(String familyId) async {
    final keep = await referenced(familyId);
    final cutoff = DateTime.now().subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    final rows = await (db.selectOnly(db.blobs)
          ..addColumns([db.blobs.id, db.blobs.created])
          ..where(db.blobs.familyId.equals(familyId)))
        .get();
    final drop = [
      for (final r in rows)
        if (!keep.contains(r.read(db.blobs.id)) && r.read(db.blobs.created)! < cutoff) r.read(db.blobs.id)!,
    ];
    if (drop.isEmpty) return 0;
    return (db.delete(db.blobs)..where((b) => b.familyId.equals(familyId) & b.id.isIn(drop))).go();
  }

  Future<void> dispose() => _added.close();
}
