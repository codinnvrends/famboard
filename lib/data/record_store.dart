import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/hlc.dart';
import '../core/ids.dart';
import '../domain/change.dart';
import '../domain/merge.dart';
import 'db/database.dart';

/// What the sync protocol needs from storage. Kept small so the protocol can
/// be tested against any store.
abstract class ChangeStore {
  /// For each origin device, the highest clock this store has from it.
  Future<Map<String, String>> versionVector(String familyId);

  /// Changes from [familyId] that a peer holding [peerVector] lacks.
  Future<List<Change>> changesSince(
    String familyId,
    Map<String, String> peerVector,
  );

  /// Stores and merges changes received from a peer. Returns how many were
  /// new to this store.
  Future<int> applyRemote(List<Change> changes);
}

/// One record write: a set of fields on one record.
class RecordWrite {
  const RecordWrite({
    required this.familyId,
    required this.entity,
    required this.id,
    required this.fields,
  });

  final String familyId;
  final String entity;
  final String id;
  final Map<String, Object?> fields;
}

/// The device's document store: merged records plus the change log they
/// were built from. All local edits and remote changes go through the same
/// merge rules, so the result is identical however changes arrive.
class RecordStore implements ChangeStore {
  RecordStore(this.db, this.clock, {this.rules = const MergeRules()});

  final AppDatabase db;
  final HlcClock clock;
  final MergeRules rules;

  final _localChanges = StreamController<String>.broadcast();
  final _remoteChanges = StreamController<String>.broadcast();

  /// Emits a family id whenever this device writes a change for it.
  Stream<String> get localChanges => _localChanges.stream;

  /// Emits a family id whenever new changes arrive from a peer.
  Stream<String> get remoteChanges => _remoteChanges.stream;

  /// Creates a store whose clock continues from the newest change on disk.
  static Future<RecordStore> open(AppDatabase db, String node) async {
    final row = await db
        .customSelect('SELECT MAX(hlc) AS m FROM changes')
        .getSingleOrNull();
    final max = row?.read<String?>('m');
    Hlc? last;
    if (max != null) {
      final h = Hlc.parse(max);
      last = Hlc(h.millis, h.counter, node);
    }
    return RecordStore(db, HlcClock(node, last: last));
  }

  // ---------------------------------------------------------------------
  // Local writes

  Future<void> write(RecordWrite write) => writeAll([write]);

  /// Writes several records atomically (e.g. an entry and its activity row).
  Future<void> writeAll(List<RecordWrite> writes) async {
    if (writes.isEmpty) return;
    final changes = <Change>[];
    for (final w in writes) {
      final hlc = clock.tick();
      for (final field in w.fields.entries) {
        changes.add(Change(
          id: newId(),
          familyId: w.familyId,
          entity: w.entity,
          recordId: w.id,
          field: field.key,
          value: field.value,
          hlc: hlc,
        ));
      }
    }
    await _store(changes);
    for (final f in writes.map((w) => w.familyId).toSet()) {
      _localChanges.add(f);
    }
  }

  Future<void> delete(String familyId, String entity, String id) => write(
        RecordWrite(
          familyId: familyId,
          entity: entity,
          id: id,
          fields: const {RecordState.deletedField: true},
        ),
      );

  // ---------------------------------------------------------------------
  // Reads

  Future<RecordState?> get(String entity, String id) async {
    final row = await (db.select(db.records)
          ..where((r) => r.entity.equals(entity) & r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toState(row);
  }

  Future<List<RecordState>> list(
    String familyId,
    String entity, {
    bool includeDeleted = false,
  }) async {
    final rows = await _query(familyId, entity, includeDeleted).get();
    return rows.map(_toState).toList();
  }

  Stream<List<RecordState>> watch(
    String familyId,
    String entity, {
    bool includeDeleted = false,
  }) =>
      _query(familyId, entity, includeDeleted)
          .watch()
          .map((rows) => rows.map(_toState).toList());

  SimpleSelectStatement<$RecordsTable, RecordRow> _query(
    String familyId,
    String entity,
    bool includeDeleted,
  ) {
    final q = db.select(db.records)
      ..where((r) => r.familyId.equals(familyId) & r.entity.equals(entity));
    if (!includeDeleted) q.where((r) => r.deleted.equals(false));
    return q;
  }

  /// Every change for a family, oldest first (backups and export).
  Future<List<Change>> allChanges(String familyId) async {
    final rows = await (db.select(db.changes)
          ..where((c) => c.familyId.equals(familyId))
          ..orderBy([(c) => OrderingTerm.asc(c.hlc)]))
        .get();
    return rows.map(_toChange).toList();
  }

  // ---------------------------------------------------------------------
  // Sync

  @override
  Future<Map<String, String>> versionVector(String familyId) async {
    final rows = await db.customSelect(
      'SELECT node, MAX(hlc) AS h FROM changes WHERE family_id = ? GROUP BY node',
      variables: [Variable.withString(familyId)],
      readsFrom: {db.changes},
    ).get();
    return {for (final r in rows) r.read<String>('node'): r.read<String>('h')};
  }

  @override
  Future<List<Change>> changesSince(
    String familyId,
    Map<String, String> peerVector,
  ) async {
    final mine = await versionVector(familyId);
    final out = <Change>[];
    for (final entry in mine.entries) {
      final peerHas = peerVector[entry.key];
      if (peerHas != null && peerHas.compareTo(entry.value) >= 0) continue;
      final q = db.select(db.changes)
        ..where((c) => c.familyId.equals(familyId) & c.node.equals(entry.key))
        ..orderBy([(c) => OrderingTerm.asc(c.hlc)]);
      if (peerHas != null) q.where((c) => c.hlc.isBiggerThanValue(peerHas));
      out.addAll((await q.get()).map(_toChange));
    }
    out.sort((a, b) => a.hlc.compareTo(b.hlc));
    return out;
  }

  @override
  Future<int> applyRemote(List<Change> changes) async {
    if (changes.isEmpty) return 0;
    final fresh = await _store(changes, remote: true);
    for (final c in changes) {
      clock.receive(c.hlc);
    }
    if (fresh > 0) {
      for (final f in changes.map((c) => c.familyId).toSet()) {
        _remoteChanges.add(f);
      }
    }
    return fresh;
  }

  /// Inserts changes not already in the log and folds them into records.
  Future<int> _store(List<Change> changes, {bool remote = false}) {
    return db.transaction(() async {
      var fresh = 0;
      final states = <(String, String), RecordState>{};
      final known = remote ? await _existingIds(changes) : <String>{};
      for (final c in changes) {
        if (!known.add(c.id) && remote) continue;
        await db.into(db.changes).insert(
              ChangesCompanion.insert(
                id: c.id,
                familyId: c.familyId,
                entity: c.entity,
                recordId: c.recordId,
                field: c.field,
                value: c.valueJson,
                hlc: c.hlc.toString(),
                node: c.node,
              ),
            );
        final key = (c.entity, c.recordId);
        var state = states[key];
        if (state == null) {
          final row = await (db.select(db.records)
                ..where(
                  (r) => r.entity.equals(c.entity) & r.id.equals(c.recordId),
                ))
              .getSingleOrNull();
          state = row == null
              ? RecordState(
                  entity: c.entity,
                  id: c.recordId,
                  familyId: c.familyId,
                )
              : _toState(row);
          states[key] = state;
        }
        rules.apply(state, c);
        fresh++;
      }
      for (final s in states.values) {
        await db.into(db.records).insertOnConflictUpdate(
              RecordsCompanion.insert(
                entity: s.entity,
                id: s.id,
                familyId: s.familyId,
                data: jsonEncode(s.fields),
                clocks: jsonEncode(s.clocks),
                deleted: Value(s.isDeleted),
                updated: s.updatedClock,
              ),
            );
      }
      return fresh;
    });
  }

  Future<Set<String>> _existingIds(List<Change> changes) async {
    final ids = changes.map((c) => c.id).toSet().toList();
    final found = <String>{};
    for (var i = 0; i < ids.length; i += 500) {
      final chunk = ids.sublist(i, i + 500 > ids.length ? ids.length : i + 500);
      final rows = await (db.selectOnly(db.changes)
            ..addColumns([db.changes.id])
            ..where(db.changes.id.isIn(chunk)))
          .get();
      found.addAll(rows.map((r) => r.read(db.changes.id)!));
    }
    return found;
  }

  Future<void> dispose() async {
    await _localChanges.close();
    await _remoteChanges.close();
  }

  static RecordState _toState(RecordRow row) => RecordState(
        entity: row.entity,
        id: row.id,
        familyId: row.familyId,
        fields: Map<String, Object?>.from(jsonDecode(row.data) as Map),
        clocks: Map<String, String>.from(jsonDecode(row.clocks) as Map),
      );

  static Change _toChange(ChangeRow row) => Change(
        id: row.id,
        familyId: row.familyId,
        entity: row.entity,
        recordId: row.recordId,
        field: row.field,
        value: jsonDecode(row.value),
        hlc: Hlc.parse(row.hlc),
      );
}
