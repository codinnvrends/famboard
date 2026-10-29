import 'dart:convert';

import '../core/hlc.dart';

/// One field-level change to one record. Changes are the unit of sync: every
/// device keeps an append-only log of them and swaps the ones a peer lacks.
class Change {
  Change({
    required this.id,
    required this.familyId,
    required this.entity,
    required this.recordId,
    required this.field,
    required this.value,
    required this.hlc,
  });

  final String id;
  final String familyId;

  /// Collection name, e.g. `entry`, `member`, `family`.
  final String entity;
  final String recordId;
  final String field;

  /// JSON-compatible value (null, bool, num, String, List or Map).
  final Object? value;
  final Hlc hlc;

  String get node => hlc.node;

  String get valueJson => jsonEncode(value);

  Map<String, Object?> toWire() => {
        'i': id,
        'f': familyId,
        'e': entity,
        'r': recordId,
        'k': field,
        'v': value,
        'h': hlc.toString(),
      };

  factory Change.fromWire(Map<String, Object?> m) => Change(
        id: m['i']! as String,
        familyId: m['f']! as String,
        entity: m['e']! as String,
        recordId: m['r']! as String,
        field: m['k']! as String,
        value: m['v'],
        hlc: Hlc.parse(m['h']! as String),
      );

  @override
  String toString() => 'Change($entity/$recordId.$field=$value @$hlc)';
}

/// The merged state of one record: its field values and, per field, the
/// clock of the change that set it.
class RecordState {
  RecordState({
    required this.entity,
    required this.id,
    required this.familyId,
    Map<String, Object?>? fields,
    Map<String, String>? clocks,
  })  : fields = fields ?? {},
        clocks = clocks ?? {};

  final String entity;
  final String id;
  final String familyId;
  final Map<String, Object?> fields;
  final Map<String, String> clocks;

  static const deletedField = '_deleted';

  /// A delete only wins over edits made before it: any field written after
  /// the delete restores the record (spec section 5, rule 4).
  bool get isDeleted {
    if (fields[deletedField] != true) return false;
    final deletedAt = clocks[deletedField];
    if (deletedAt == null) return false;
    for (final entry in clocks.entries) {
      if (entry.key == deletedField) continue;
      if (entry.value.compareTo(deletedAt) > 0) return false;
    }
    return true;
  }

  /// Latest clock across all fields: when the record last changed.
  String get updatedClock =>
      clocks.values.fold('', (a, b) => b.compareTo(a) > 0 ? b : a);

  RecordState copy() => RecordState(
        entity: entity,
        id: id,
        familyId: familyId,
        fields: Map.of(fields),
        clocks: Map.of(clocks),
      );
}
