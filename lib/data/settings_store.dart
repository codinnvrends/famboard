import 'dart:convert';

import 'package:drift/drift.dart';

import 'db/database.dart';

/// A family this device belongs to, as remembered locally.
class LocalFamily {
  const LocalFamily({
    required this.id,
    required this.name,
    required this.memberId,
  });

  final String id;

  /// Name from the invite or creation; the synced family record wins once
  /// it arrives.
  final String name;

  /// This device's member in that family.
  final String memberId;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'memberId': memberId};

  factory LocalFamily.fromJson(Map<String, Object?> j) => LocalFamily(
        id: j['id']! as String,
        name: j['name'] as String? ?? '',
        memberId: j['memberId']! as String,
      );
}

/// Device-local preferences and identity. Never synced.
class SettingsStore {
  SettingsStore(this.db);

  final AppDatabase db;

  static const kDeviceId = 'deviceId';
  static const kDeviceName = 'deviceName';
  static const kFamilies = 'families';
  static const kActiveFamily = 'activeFamily';
  static const kLocale = 'locale';
  static const kLargeText = 'largeText';
  static const kDigestTime = 'digestTime';
  static const kNotifications = 'notifications';
  static const kBillLeadDays = 'billLeadDays';
  static const kNearby = 'nearbyEnabled';
  static String lastSyncKey(String familyId) => 'lastSync.$familyId';

  Future<String?> get(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Emits when [key]'s value changes. Drift re-runs the query on every
  /// write to the table, so repeats are filtered out here.
  Stream<String?> watch(String key) =>
      (db.select(db.settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((r) => r?.value)
          .distinct();

  Future<void> set(String key, String? value) async {
    if (value == null) {
      await (db.delete(db.settings)..where((s) => s.key.equals(key))).go();
    } else {
      await db
          .into(db.settings)
          .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
    }
  }

  Future<List<LocalFamily>> families() async => _decodeFamilies(await get(kFamilies));

  Stream<List<LocalFamily>> watchFamilies() => watch(kFamilies).map(_decodeFamilies);

  Future<void> upsertFamily(LocalFamily family) async {
    final list = await families();
    final i = list.indexWhere((f) => f.id == family.id);
    if (i >= 0) {
      list[i] = family;
    } else {
      list.add(family);
    }
    await set(kFamilies, jsonEncode(list.map((f) => f.toJson()).toList()));
  }

  Future<void> removeFamily(String familyId) async {
    final list = (await families())..removeWhere((f) => f.id == familyId);
    await set(kFamilies, jsonEncode(list.map((f) => f.toJson()).toList()));
    if (await get(kActiveFamily) == familyId) {
      await set(kActiveFamily, list.isEmpty ? null : list.first.id);
    }
  }

  static List<LocalFamily> _decodeFamilies(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<Object?>;
    return list
        .map((e) => LocalFamily.fromJson(Map<String, Object?>.from(e! as Map)))
        .toList();
  }

  // Peers ------------------------------------------------------------------

  Future<void> recordPeer({
    required String deviceId,
    required String familyId,
    required String name,
    required String transport,
    bool synced = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = await (db.select(db.peers)
          ..where((p) => p.deviceId.equals(deviceId) & p.familyId.equals(familyId)))
        .getSingleOrNull();
    await db.into(db.peers).insertOnConflictUpdate(
          PeersCompanion.insert(
            deviceId: deviceId,
            familyId: familyId,
            name: name,
            transport: transport,
            lastSeen: now,
            lastSync: Value(synced ? now : existing?.lastSync),
          ),
        );
  }

  /// Every family device this phone has seen.
  Future<Set<String>> knownDeviceIds() async =>
      (await db.select(db.peers).get()).map((p) => p.deviceId).toSet();

  Stream<List<PeerRow>> watchPeers(String familyId) => (db.select(db.peers)
        ..where((p) => p.familyId.equals(familyId))
        ..orderBy([(p) => OrderingTerm.desc(p.lastSeen)]))
      .watch();
}
