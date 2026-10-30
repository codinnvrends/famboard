import '../core/hlc.dart';
import 'change.dart';
import 'merge.dart';

/// Collection names used in the change log.
abstract final class Entities {
  static const family = 'family';
  static const member = 'member';
  static const entry = 'entry';
  static const activity = 'activity';
  static const keywordOverride = 'keyword_override';
  static const category = 'category';
}

enum EntryType {
  needToBuy('need_to_buy'),
  outOfStock('out_of_stock'),
  repair('repair'),
  upgrade('upgrade'),
  bill('bill'),
  task('task');

  const EntryType(this.code);
  final String code;

  static EntryType fromCode(Object? code) => EntryType.values.firstWhere(
        (t) => t.code == code,
        orElse: () => EntryType.needToBuy,
      );

  bool get isShopping => this == needToBuy || this == outOfStock;
}

enum EntryStatus {
  proposed('proposed'),
  open('open'),
  inProgress('in_progress'),
  done('done'),
  cancelled('cancelled');

  const EntryStatus(this.code);
  final String code;

  static EntryStatus fromCode(Object? code) => EntryStatus.values.firstWhere(
        (s) => s.code == code,
        orElse: () => EntryStatus.open,
      );

  bool get isClosed => this == done || this == cancelled;
}

enum Priority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const Priority(this.code);
  final String code;

  static Priority fromCode(Object? code) => Priority.values.firstWhere(
        (p) => p.code == code,
        orElse: () => Priority.normal,
      );

  bool get isHighOrAbove => this == high || this == urgent;
}

enum Role {
  admin('admin'),
  member('member'),
  child('child'),
  viewer('viewer');

  const Role(this.code);
  final String code;

  static Role fromCode(Object? code) => Role.values.firstWhere(
        (r) => r.code == code,
        orElse: () => Role.member,
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;
double? _num(Object? v) => v is num ? v.toDouble() : null;
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;

DateTime _clockTime(String clock) {
  if (clock.isEmpty) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.fromMillisecondsSinceEpoch(Hlc.parse(clock).millis);
}

class Family {
  const Family({
    required this.id,
    required this.name,
    this.createdBy,
    this.approvalsOn = false,
  });

  final String id;
  final String name;
  final String? createdBy;
  final bool approvalsOn;

  factory Family.fromRecord(RecordState r) => Family(
        id: r.id,
        name: _str(r.fields['name']) ?? 'Family',
        createdBy: _str(r.fields['createdBy']),
        approvalsOn: r.fields['approvalsOn'] == true,
      );
}

class Member {
  const Member({
    required this.id,
    required this.familyId,
    required this.name,
    required this.role,
    this.color = 0,
    this.removed = false,
  });

  final String id;
  final String familyId;
  final String name;
  final Role role;
  final int color;
  final bool removed;

  factory Member.fromRecord(RecordState r) => Member(
        id: r.id,
        familyId: r.familyId,
        name: _str(r.fields['name']) ?? '?',
        role: Role.fromCode(r.fields['role']),
        color: (r.fields['color'] as num?)?.toInt() ?? 0,
        removed: r.fields['removed'] == true,
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters(1).toUpperCase();
    return (parts.first.characters(1) + parts.last.characters(1)).toUpperCase();
  }
}

extension on String {
  String characters(int n) => runes.take(n).map(String.fromCharCode).join();
}

class Entry {
  const Entry({
    required this.id,
    required this.familyId,
    required this.title,
    required this.type,
    required this.categoryId,
    required this.priority,
    required this.status,
    this.statusEpoch = 0,
    this.quantity,
    this.unit,
    this.amount,
    this.dueAt,
    this.assigneeId,
    this.note,
    this.rrule,
    this.seriesId,
    this.leadDays,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    required this.updatedAt,
    this.doneAt,
    this.deleted = false,
  });

  final String id;
  final String familyId;
  final String title;
  final EntryType type;
  final String categoryId;
  final Priority priority;
  final EntryStatus status;
  final int statusEpoch;
  final double? quantity;
  final String? unit;
  final double? amount;
  final DateTime? dueAt;
  final String? assigneeId;
  final String? note;

  /// Recurrence rule (RRULE subset), present on recurring entries.
  final String? rrule;

  /// Groups occurrences of the same recurring entry.
  final String? seriesId;

  /// Days before [dueAt] to send the early reminder.
  final int? leadDays;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final DateTime updatedAt;

  /// When the entry was last marked done.
  final DateTime? doneAt;
  final bool deleted;

  bool get isRecurring => rrule != null && rrule!.isNotEmpty;
  bool get isOpen => !status.isClosed && !deleted;

  factory Entry.fromRecord(RecordState r) {
    final f = r.fields;
    final status = StatusValue.fromJson(f['status']);
    return Entry(
      id: r.id,
      familyId: r.familyId,
      title: _str(f['title']) ?? '',
      type: EntryType.fromCode(f['type']),
      categoryId: _str(f['categoryId']) ?? 'other',
      priority: Priority.fromCode(f['priority']),
      status: EntryStatus.fromCode(status.status),
      statusEpoch: status.epoch,
      quantity: _num(f['quantity']),
      unit: _str(f['unit']),
      amount: _num(f['amount']),
      dueAt: _date(f['dueAt']),
      assigneeId: _str(f['assigneeId']),
      note: _str(f['note']),
      rrule: _str(f['rrule']),
      seriesId: _str(f['seriesId']),
      leadDays: (f['leadDays'] as num?)?.toInt(),
      createdBy: _str(f['createdBy']),
      createdAt: _date(f['createdAt']),
      updatedBy: _str(f['updatedBy']),
      updatedAt: _clockTime(r.updatedClock),
      doneAt: _date(f['doneAt']),
      deleted: r.isDeleted,
    );
  }

  /// The fields that describe this entry, for writing.
  Map<String, Object?> toFields() => {
        'title': title,
        'type': type.code,
        'categoryId': categoryId,
        'priority': priority.code,
        'status': StatusValue(status.code, statusEpoch).toJson(),
        'quantity': quantity,
        'unit': unit,
        'amount': amount,
        'dueAt': dueAt?.toIso8601String(),
        'assigneeId': assigneeId,
        'note': note,
        'rrule': rrule,
        'seriesId': seriesId,
        'leadDays': leadDays,
      };
}

class Activity {
  const Activity({
    required this.id,
    required this.entryId,
    required this.memberId,
    required this.action,
    required this.at,
    this.detail,
  });

  final String id;
  final String entryId;
  final String memberId;

  /// created, edited, claimed, unclaimed, status, deleted, restored, bought.
  final String action;
  final String? detail;
  final DateTime at;

  factory Activity.fromRecord(RecordState r) => Activity(
        id: r.id,
        entryId: _str(r.fields['entryId']) ?? '',
        memberId: _str(r.fields['memberId']) ?? '',
        action: _str(r.fields['action']) ?? 'edited',
        detail: _str(r.fields['detail']),
        at: _date(r.fields['at']) ?? _clockTime(r.updatedClock),
      );
}

/// A family's learned word → category mapping (spec section 6, layer 1).
class KeywordOverride {
  const KeywordOverride({
    required this.term,
    required this.categoryId,
    this.type,
  });

  final String term;
  final String categoryId;
  final EntryType? type;

  factory KeywordOverride.fromRecord(RecordState r) => KeywordOverride(
        term: _str(r.fields['term']) ?? '',
        categoryId: _str(r.fields['categoryId']) ?? 'other',
        type: r.fields['type'] == null
            ? null
            : EntryType.fromCode(r.fields['type']),
      );
}

/// A category a family added on top of the built-in tree.
class CustomCategory {
  const CustomCategory({
    required this.id,
    required this.name,
    required this.parentId,
  });

  final String id;
  final String name;
  final String parentId;

  factory CustomCategory.fromRecord(RecordState r) => CustomCategory(
        id: r.id,
        name: _str(r.fields['name']) ?? '?',
        parentId: _str(r.fields['parentId']) ?? 'other',
      );
}
