import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart';
import '../data/settings_store.dart';
import '../domain/models.dart';
import '../domain/permissions.dart';
import '../sync/sync_manager.dart';
import 'services.dart';

/// Overridden in `main` with the real services.
final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('servicesProvider must be overridden'),
);

final familiesProvider = StreamProvider<List<LocalFamily>>((ref) {
  final s = ref.watch(servicesProvider).settings;
  return s.watchFamilies();
});

final activeFamilyIdProvider = StreamProvider<String?>((ref) {
  return ref.watch(servicesProvider).settings.watch(SettingsStore.kActiveFamily);
});

/// The family on screen and this device's member in it.
class FamilySession {
  const FamilySession(this.local);
  final LocalFamily local;
  String get familyId => local.id;
  String get memberId => local.memberId;
}

final sessionProvider = Provider<FamilySession?>((ref) {
  final families = ref.watch(familiesProvider).value ?? const [];
  if (families.isEmpty) return null;
  final active = ref.watch(activeFamilyIdProvider).value;
  final local = families.where((f) => f.id == active).firstOrNull ?? families.first;
  return FamilySession(local);
});

final familyProvider = StreamProvider.family<Family?, String>((ref, familyId) {
  return ref.watch(servicesProvider).repo.watchFamily(familyId);
});

/// Display name: the synced family record, or the name from the invite.
final familyNameProvider = Provider<String>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return '';
  final family = ref.watch(familyProvider(session.familyId)).value;
  return family?.name ?? session.local.name;
});

final membersProvider = StreamProvider.family<List<Member>, String>((ref, familyId) {
  return ref.watch(servicesProvider).repo.watchMembers(familyId);
});

final entriesProvider = StreamProvider.family<List<Entry>, String>((ref, familyId) {
  return ref.watch(servicesProvider).repo.watchEntries(familyId);
});

final allEntriesProvider = StreamProvider.family<List<Entry>, String>((ref, familyId) {
  return ref.watch(servicesProvider).repo.watchEntries(familyId, includeDeleted: true);
});

final overridesProvider = StreamProvider.family<List<KeywordOverride>, String>((ref, familyId) {
  return ref.watch(servicesProvider).repo.watchOverrides(familyId);
});

final customCategoriesProvider =
    StreamProvider.family<List<CustomCategory>, String>((ref, familyId) {
  return ref.watch(servicesProvider).repo.watchCustomCategories(familyId);
});

/// This device's member record (null until it is written or synced).
final meProvider = Provider<Member?>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return null;
  final members = ref.watch(membersProvider(session.familyId)).value ?? const [];
  return members.where((m) => m.id == session.memberId).firstOrNull;
});

final permsProvider = Provider<Perms>((ref) {
  final session = ref.watch(sessionProvider);
  final me = ref.watch(meProvider);
  return Perms(me?.role ?? Role.member, session?.memberId ?? '');
});

final memberNamesProvider = Provider<Map<String, String>>((ref) {
  final session = ref.watch(sessionProvider);
  if (session == null) return const {};
  final members = ref.watch(membersProvider(session.familyId)).value ?? const [];
  return {for (final m in members) m.id: m.name};
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final sync = ref.watch(servicesProvider).sync;
  yield sync.current;
  yield* sync.status;
});

final lastSyncProvider = StreamProvider.family<LastSync?, String>((ref, familyId) {
  return ref
      .watch(servicesProvider)
      .settings
      .watch(SettingsStore.lastSyncKey(familyId))
      .map(LastSync.decode);
});

final knownPeersProvider = StreamProvider.family<List<PeerRow>, String>((ref, familyId) {
  return ref.watch(servicesProvider).settings.watchPeers(familyId);
});

final settingProvider = StreamProvider.family<String?, String>((ref, key) {
  return ref.watch(servicesProvider).settings.watch(key);
});
