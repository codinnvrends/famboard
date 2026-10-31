import 'dart:math';

import '../core/ids.dart';
import '../core/text.dart';
import '../domain/change.dart';
import '../domain/invite.dart';
import '../domain/merge.dart';
import '../domain/models.dart';
import '../services/categorizer/categorizer.dart';
import '../services/recurrence.dart';
import 'key_vault.dart';
import 'record_store.dart';
import 'settings_store.dart';

/// Fields for a new entry.
class EntryDraft {
  const EntryDraft({
    required this.title,
    required this.type,
    required this.categoryId,
    this.priority = Priority.normal,
    this.quantity,
    this.unit,
    this.amount,
    this.dueAt,
    this.assigneeId,
    this.note,
    this.rrule,
    this.leadDays,
    this.proposed = false,
  });

  final String title;
  final EntryType type;
  final String categoryId;
  final Priority priority;
  final double? quantity;
  final String? unit;
  final double? amount;
  final DateTime? dueAt;
  final String? assigneeId;
  final String? note;
  final String? rrule;
  final int? leadDays;
  final bool proposed;
}

/// Family and entry operations. Everything is a local write; sync carries it
/// to the rest of the family.
class FamBoardRepository {
  FamBoardRepository({
    required this.store,
    required this.settings,
    required this.vault,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final RecordStore store;
  final SettingsStore settings;
  final KeyVault vault;
  final DateTime Function() _now;

  static const _memberColors = 8;

  // Families ----------------------------------------------------------------

  /// Creates a family with this device's user as its first admin.
  Future<LocalFamily> createFamily({
    required String familyName,
    required String myName,
  }) async {
    final familyId = newId();
    final memberId = newId();
    await vault.saveFamilyKey(familyId, KeyVault.randomKey());
    await store.writeAll([
      RecordWrite(
        familyId: familyId,
        entity: Entities.family,
        id: familyId,
        fields: {'name': familyName.trim(), 'createdBy': memberId, 'approvalsOn': false},
      ),
      _memberWrite(familyId, memberId, myName, Role.admin),
    ]);
    final local = LocalFamily(id: familyId, name: familyName.trim(), memberId: memberId);
    await settings.upsertFamily(local);
    await settings.set(SettingsStore.kActiveFamily, familyId);
    return local;
  }

  /// Joins a family from a scanned invite. Family data arrives on first sync.
  /// Joins from a scanned invite. For a returning member ([FamilyInvite
  /// .isReturning]) this phone takes over their existing member record, so
  /// their name, role and history come back on first sync. [myName] is
  /// ignored then.
  Future<LocalFamily> joinFamily(FamilyInvite invite, {required String myName}) async {
    if (invite.isExpired(_now())) {
      throw StateError('This invite has expired. Ask for a new QR code.');
    }
    final existing = (await settings.families())
        .where((f) => f.id == invite.familyId)
        .firstOrNull;
    if (existing != null) return existing;
    final memberId = invite.memberId ?? newId();
    await vault.saveFamilyKey(invite.familyId, invite.key);
    if (invite.isReturning) {
      await store.write(RecordWrite(
        familyId: invite.familyId,
        entity: Entities.member,
        id: memberId,
        fields: {'rejoinedAt': _now().toIso8601String(), 'rejoinedVia': invite.invitedBy},
      ));
    } else {
      await store.write(_memberWrite(invite.familyId, memberId, myName, invite.role));
    }
    final local = LocalFamily(
      id: invite.familyId,
      name: invite.familyName,
      memberId: memberId,
    );
    await settings.upsertFamily(local);
    await settings.set(SettingsStore.kActiveFamily, invite.familyId);
    return local;
  }

  /// Creates a QR invite. Pass [returning] to invite back an existing
  /// member (their role is kept); otherwise a new member joins with [role].
  Future<FamilyInvite> createInvite({
    required String familyId,
    required String familyName,
    required String invitedBy,
    required Role role,
    Member? returning,
  }) async {
    final key = await vault.familyKey(familyId);
    if (key == null) throw StateError('Family key missing on this device');
    if (returning != null && returning.removed) {
      // Only admins see removed members in the picker; inviting them back
      // reinstates them.
      await store.write(RecordWrite(
        familyId: familyId,
        entity: Entities.member,
        id: returning.id,
        fields: const {'removed': false},
      ));
    }
    return FamilyInvite(
      familyId: familyId,
      familyName: familyName,
      key: key,
      role: returning?.role ?? role,
      invitedBy: invitedBy,
      expiresAt: _now().add(FamilyInvite.validFor),
      memberId: returning?.id,
      memberName: returning?.name,
    );
  }

  Future<void> renameFamily(String familyId, String name) => store.write(RecordWrite(
        familyId: familyId,
        entity: Entities.family,
        id: familyId,
        fields: {'name': name.trim()},
      ));

  RecordWrite _memberWrite(String familyId, String id, String name, Role role) =>
      RecordWrite(
        familyId: familyId,
        entity: Entities.member,
        id: id,
        fields: {
          'name': name.trim(),
          'role': role.code,
          'color': Random().nextInt(_memberColors),
          'removed': false,
        },
      );

  Stream<Family?> watchFamily(String familyId) => store
      .watch(familyId, Entities.family)
      .map((l) => l.isEmpty ? null : Family.fromRecord(l.first));

  Stream<List<Member>> watchMembers(String familyId) =>
      store.watch(familyId, Entities.member).map(
            (l) => l.map(Member.fromRecord).toList()
              ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
          );

  Future<List<Member>> members(String familyId) async =>
      (await store.list(familyId, Entities.member)).map(Member.fromRecord).toList();

  Future<void> setMemberRole(String familyId, String memberId, Role role) =>
      store.write(RecordWrite(
        familyId: familyId,
        entity: Entities.member,
        id: memberId,
        fields: {'role': role.code},
      ));

  Future<void> renameMember(String familyId, String memberId, String name) =>
      store.write(RecordWrite(
        familyId: familyId,
        entity: Entities.member,
        id: memberId,
        fields: {'name': name.trim()},
      ));

  /// Marks a member removed; their devices are refused at the next sync.
  Future<void> removeMember(String familyId, String memberId) => store.write(RecordWrite(
        familyId: familyId,
        entity: Entities.member,
        id: memberId,
        fields: {'removed': true},
      ));

  // Entries -----------------------------------------------------------------

  Stream<List<Entry>> watchEntries(String familyId, {bool includeDeleted = false}) =>
      store
          .watch(familyId, Entities.entry, includeDeleted: includeDeleted)
          .map((l) => l.map(Entry.fromRecord).toList());

  Future<List<Entry>> entries(String familyId) async =>
      (await store.list(familyId, Entities.entry)).map(Entry.fromRecord).toList();

  Stream<Entry?> watchEntry(String familyId, String id) => store
      .watch(familyId, Entities.entry, includeDeleted: true)
      .map((l) => l.where((r) => r.id == id).map(Entry.fromRecord).firstOrNull);

  Stream<List<Activity>> watchActivity(String familyId, String entryId) => store
      .watch(familyId, Entities.activity)
      .map((l) => l
          .map(Activity.fromRecord)
          .where((a) => a.entryId == entryId)
          .toList()
        ..sort((a, b) => b.at.compareTo(a.at)));

  Future<String> addEntry({
    required String familyId,
    required String memberId,
    required EntryDraft draft,
    String? id,
  }) async {
    final entryId = id ?? newId();
    final status = draft.proposed ? EntryStatus.proposed : EntryStatus.open;
    final rrule = draft.rrule;
    await store.writeAll([
      RecordWrite(
        familyId: familyId,
        entity: Entities.entry,
        id: entryId,
        fields: {
          'title': draft.title.trim(),
          'type': draft.type.code,
          'categoryId': draft.categoryId,
          'priority': draft.priority.code,
          'status': StatusValue(status.code, 0).toJson(),
          'quantity': draft.quantity,
          'unit': draft.unit,
          'amount': draft.amount,
          'dueAt': draft.dueAt?.toIso8601String(),
          'assigneeId': draft.assigneeId,
          'note': draft.note,
          'rrule': rrule,
          'seriesId': rrule == null ? null : entryId,
          'leadDays': draft.leadDays,
          'createdBy': memberId,
          'createdAt': _now().toIso8601String(),
          'updatedBy': memberId,
        },
      ),
      _activity(familyId, entryId, memberId, 'created'),
    ]);
    return entryId;
  }

  /// Writes only the fields that changed.
  Future<void> updateEntry({
    required Entry before,
    required String memberId,
    required Map<String, Object?> changes,
  }) async {
    final current = before.toFields();
    final changed = <String, Object?>{
      for (final e in changes.entries)
        if (current[e.key] != e.value) e.key: e.value,
    };
    if (changed.isEmpty) return;
    if (changed.containsKey('rrule') && changed['rrule'] != null && before.seriesId == null) {
      changed['seriesId'] = before.id;
    }
    changed['updatedBy'] = memberId;
    await store.writeAll([
      RecordWrite(
        familyId: before.familyId,
        entity: Entities.entry,
        id: before.id,
        fields: changed,
      ),
      _activity(
        before.familyId,
        before.id,
        memberId,
        'edited',
        detail: changed.keys.where((k) => k != 'updatedBy' && k != 'seriesId').join(','),
      ),
    ]);
  }

  /// Changes status. Completing a recurring entry creates its next occurrence
  /// with a deterministic id, so two phones completing it offline don't
  /// create two copies.
  Future<String?> setStatus({
    required Entry entry,
    required String memberId,
    required EntryStatus status,
    String activity = 'status',
  }) async {
    final reopening = entry.status.isClosed && !status.isClosed;
    final epoch = reopening ? entry.statusEpoch + 1 : entry.statusEpoch;
    final writes = <RecordWrite>[
      RecordWrite(
        familyId: entry.familyId,
        entity: Entities.entry,
        id: entry.id,
        fields: {
          'status': StatusValue(status.code, epoch).toJson(),
          'updatedBy': memberId,
          if (status == EntryStatus.done) 'doneAt': _now().toIso8601String(),
        },
      ),
      _activity(entry.familyId, entry.id, memberId, activity, detail: status.code),
    ];
    String? nextId;
    final rule = RecurrenceRule.tryParse(entry.rrule);
    if (status == EntryStatus.done && rule != null && !entry.status.isClosed) {
      final nextDue = rule.nextDue(due: entry.dueAt, completedOn: _now());
      final series = entry.seriesId ?? entry.id;
      nextId = stableId(['occurrence', series, _dateKey(nextDue)]);
      writes.add(RecordWrite(
        familyId: entry.familyId,
        entity: Entities.entry,
        id: nextId,
        fields: {
          ...entry.toFields(),
          'status': StatusValue(EntryStatus.open.code, 0).toJson(),
          'dueAt': nextDue.toIso8601String(),
          'seriesId': series,
          'assigneeId': null,
          'createdBy': memberId,
          'createdAt': _now().toIso8601String(),
          'updatedBy': memberId,
        },
      ));
      writes.add(_activity(entry.familyId, nextId, memberId, 'created', detail: 'recurring'));
      // The completed occurrence keeps its history but stops recurring.
      writes.first.fields['rrule'] = null;
    }
    await store.writeAll(writes);
    return nextId;
  }

  Future<void> claim(Entry entry, String memberId, {required bool claim}) =>
      store.writeAll([
        RecordWrite(
          familyId: entry.familyId,
          entity: Entities.entry,
          id: entry.id,
          fields: {
            'assigneeId': claim ? memberId : null,
            if (claim && entry.status == EntryStatus.open)
              'status': StatusValue(EntryStatus.inProgress.code, entry.statusEpoch).toJson(),
            'updatedBy': memberId,
          },
        ),
        _activity(entry.familyId, entry.id, memberId, claim ? 'claimed' : 'unclaimed'),
      ]);

  Future<void> deleteEntry(Entry entry, String memberId) => store.writeAll([
        RecordWrite(
          familyId: entry.familyId,
          entity: Entities.entry,
          id: entry.id,
          fields: {RecordState.deletedField: true},
        ),
        _activity(entry.familyId, entry.id, memberId, 'deleted'),
      ]);

  /// Restores a soft-deleted entry: any write after the delete restores it.
  Future<void> restoreEntry(Entry entry, String memberId) => store.writeAll([
        RecordWrite(
          familyId: entry.familyId,
          entity: Entities.entry,
          id: entry.id,
          fields: {RecordState.deletedField: false, 'updatedBy': memberId},
        ),
        _activity(entry.familyId, entry.id, memberId, 'restored'),
      ]);

  /// Open entries that look like the same item (spec FR-14).
  List<Entry> findDuplicates(List<Entry> open, String title, {String? excludeId}) {
    final key = duplicateKey(title);
    if (key.isEmpty) return const [];
    return open
        .where((e) => e.id != excludeId && e.isOpen && duplicateKey(e.title) == key)
        .toList();
  }

  static String duplicateKey(String title) {
    final tokens = tokenize(title)
        .where((t) => !stopWords.contains(t) && double.tryParse(t) == null)
        .map((t) => t.length > 3 && t.endsWith('s') ? t.substring(0, t.length - 1) : t)
        .toSet()
        .toList()
      ..sort();
    return tokens.join(' ');
  }

  // Categories ----------------------------------------------------------------

  Stream<List<KeywordOverride>> watchOverrides(String familyId) => store
      .watch(familyId, Entities.keywordOverride)
      .map((l) => l.map(KeywordOverride.fromRecord).toList());

  Future<List<KeywordOverride>> overrides(String familyId) async =>
      (await store.list(familyId, Entities.keywordOverride))
          .map(KeywordOverride.fromRecord)
          .toList();

  /// Remembers a user's correction so the whole family's phones categorize
  /// this title the same way next time.
  Future<void> learnCategory({
    required String familyId,
    required String title,
    required String categoryId,
    EntryType? type,
  }) async {
    final terms = Categorizer.learnableTerms(title);
    if (terms.isEmpty) return;
    await store.writeAll([
      for (final term in terms)
        RecordWrite(
          familyId: familyId,
          entity: Entities.keywordOverride,
          id: stableId(['kw', familyId, term]),
          fields: {'term': term, 'categoryId': categoryId, 'type': type?.code},
        ),
    ]);
  }

  Stream<List<CustomCategory>> watchCustomCategories(String familyId) => store
      .watch(familyId, Entities.category)
      .map((l) => l.map(CustomCategory.fromRecord).toList());

  Future<String> addCustomCategory(String familyId, String name, String parentId) async {
    final id = '$parentId.custom-${newId().substring(0, 8)}';
    await store.write(RecordWrite(
      familyId: familyId,
      entity: Entities.category,
      id: id,
      fields: {'name': name.trim(), 'parentId': parentId},
    ));
    return id;
  }

  // Helpers -------------------------------------------------------------------

  RecordWrite _activity(
    String familyId,
    String entryId,
    String memberId,
    String action, {
    String? detail,
  }) =>
      RecordWrite(
        familyId: familyId,
        entity: Entities.activity,
        id: newId(),
        fields: {
          'entryId': entryId,
          'memberId': memberId,
          'action': action,
          'detail': detail,
          'at': _now().toIso8601String(),
        },
      );

  static String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
