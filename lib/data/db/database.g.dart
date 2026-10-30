// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clocksMeta = const VerificationMeta('clocks');
  @override
  late final GeneratedColumn<String> clocks = GeneratedColumn<String>(
    'clocks',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedMeta = const VerificationMeta(
    'updated',
  );
  @override
  late final GeneratedColumn<String> updated = GeneratedColumn<String>(
    'updated',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    entity,
    id,
    familyId,
    data,
    clocks,
    deleted,
    updated,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    } else if (isInserting) {
      context.missing(_dataMeta);
    }
    if (data.containsKey('clocks')) {
      context.handle(
        _clocksMeta,
        clocks.isAcceptableOrUnknown(data['clocks']!, _clocksMeta),
      );
    } else if (isInserting) {
      context.missing(_clocksMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated')) {
      context.handle(
        _updatedMeta,
        updated.isAcceptableOrUnknown(data['updated']!, _updatedMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {entity, id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      clocks: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}clocks'],
      )!,
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updated: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated'],
      )!,
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  final String entity;
  final String id;
  final String familyId;

  /// JSON object: field → value.
  final String data;

  /// JSON object: field → HLC of the change that set it.
  final String clocks;
  final bool deleted;

  /// Highest clock across fields; orders "recently changed".
  final String updated;
  const RecordRow({
    required this.entity,
    required this.id,
    required this.familyId,
    required this.data,
    required this.clocks,
    required this.deleted,
    required this.updated,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['entity'] = Variable<String>(entity);
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['data'] = Variable<String>(data);
    map['clocks'] = Variable<String>(clocks);
    map['deleted'] = Variable<bool>(deleted);
    map['updated'] = Variable<String>(updated);
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      entity: Value(entity),
      id: Value(id),
      familyId: Value(familyId),
      data: Value(data),
      clocks: Value(clocks),
      deleted: Value(deleted),
      updated: Value(updated),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      entity: serializer.fromJson<String>(json['entity']),
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      data: serializer.fromJson<String>(json['data']),
      clocks: serializer.fromJson<String>(json['clocks']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updated: serializer.fromJson<String>(json['updated']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'entity': serializer.toJson<String>(entity),
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'data': serializer.toJson<String>(data),
      'clocks': serializer.toJson<String>(clocks),
      'deleted': serializer.toJson<bool>(deleted),
      'updated': serializer.toJson<String>(updated),
    };
  }

  RecordRow copyWith({
    String? entity,
    String? id,
    String? familyId,
    String? data,
    String? clocks,
    bool? deleted,
    String? updated,
  }) => RecordRow(
    entity: entity ?? this.entity,
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    data: data ?? this.data,
    clocks: clocks ?? this.clocks,
    deleted: deleted ?? this.deleted,
    updated: updated ?? this.updated,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      entity: data.entity.present ? data.entity.value : this.entity,
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      data: data.data.present ? data.data.value : this.data,
      clocks: data.clocks.present ? data.clocks.value : this.clocks,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updated: data.updated.present ? data.updated.value : this.updated,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('entity: $entity, ')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('data: $data, ')
          ..write('clocks: $clocks, ')
          ..write('deleted: $deleted, ')
          ..write('updated: $updated')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(entity, id, familyId, data, clocks, deleted, updated);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          other.entity == this.entity &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.data == this.data &&
          other.clocks == this.clocks &&
          other.deleted == this.deleted &&
          other.updated == this.updated);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<String> entity;
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> data;
  final Value<String> clocks;
  final Value<bool> deleted;
  final Value<String> updated;
  final Value<int> rowid;
  const RecordsCompanion({
    this.entity = const Value.absent(),
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.data = const Value.absent(),
    this.clocks = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updated = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String entity,
    required String id,
    required String familyId,
    required String data,
    required String clocks,
    this.deleted = const Value.absent(),
    required String updated,
    this.rowid = const Value.absent(),
  }) : entity = Value(entity),
       id = Value(id),
       familyId = Value(familyId),
       data = Value(data),
       clocks = Value(clocks),
       updated = Value(updated);
  static Insertable<RecordRow> custom({
    Expression<String>? entity,
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? data,
    Expression<String>? clocks,
    Expression<bool>? deleted,
    Expression<String>? updated,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (entity != null) 'entity': entity,
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (data != null) 'data': data,
      if (clocks != null) 'clocks': clocks,
      if (deleted != null) 'deleted': deleted,
      if (updated != null) 'updated': updated,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? entity,
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? data,
    Value<String>? clocks,
    Value<bool>? deleted,
    Value<String>? updated,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      entity: entity ?? this.entity,
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      data: data ?? this.data,
      clocks: clocks ?? this.clocks,
      deleted: deleted ?? this.deleted,
      updated: updated ?? this.updated,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (clocks.present) {
      map['clocks'] = Variable<String>(clocks.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updated.present) {
      map['updated'] = Variable<String>(updated.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('entity: $entity, ')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('data: $data, ')
          ..write('clocks: $clocks, ')
          ..write('deleted: $deleted, ')
          ..write('updated: $updated, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChangesTable extends Changes with TableInfo<$ChangesTable, ChangeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChangesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
    'entity',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fieldMeta = const VerificationMeta('field');
  @override
  late final GeneratedColumn<String> field = GeneratedColumn<String>(
    'field',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hlcMeta = const VerificationMeta('hlc');
  @override
  late final GeneratedColumn<String> hlc = GeneratedColumn<String>(
    'hlc',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nodeMeta = const VerificationMeta('node');
  @override
  late final GeneratedColumn<String> node = GeneratedColumn<String>(
    'node',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    familyId,
    entity,
    recordId,
    field,
    value,
    hlc,
    node,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'changes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChangeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('entity')) {
      context.handle(
        _entityMeta,
        entity.isAcceptableOrUnknown(data['entity']!, _entityMeta),
      );
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recordIdMeta);
    }
    if (data.containsKey('field')) {
      context.handle(
        _fieldMeta,
        field.isAcceptableOrUnknown(data['field']!, _fieldMeta),
      );
    } else if (isInserting) {
      context.missing(_fieldMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('hlc')) {
      context.handle(
        _hlcMeta,
        hlc.isAcceptableOrUnknown(data['hlc']!, _hlcMeta),
      );
    } else if (isInserting) {
      context.missing(_hlcMeta);
    }
    if (data.containsKey('node')) {
      context.handle(
        _nodeMeta,
        node.isAcceptableOrUnknown(data['node']!, _nodeMeta),
      );
    } else if (isInserting) {
      context.missing(_nodeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChangeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChangeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      entity: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      )!,
      field: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}field'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      hlc: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hlc'],
      )!,
      node: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}node'],
      )!,
    );
  }

  @override
  $ChangesTable createAlias(String alias) {
    return $ChangesTable(attachedDatabase, alias);
  }
}

class ChangeRow extends DataClass implements Insertable<ChangeRow> {
  final String id;
  final String familyId;
  final String entity;
  final String recordId;
  final String field;

  /// JSON-encoded value.
  final String value;
  final String hlc;
  final String node;
  const ChangeRow({
    required this.id,
    required this.familyId,
    required this.entity,
    required this.recordId,
    required this.field,
    required this.value,
    required this.hlc,
    required this.node,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['family_id'] = Variable<String>(familyId);
    map['entity'] = Variable<String>(entity);
    map['record_id'] = Variable<String>(recordId);
    map['field'] = Variable<String>(field);
    map['value'] = Variable<String>(value);
    map['hlc'] = Variable<String>(hlc);
    map['node'] = Variable<String>(node);
    return map;
  }

  ChangesCompanion toCompanion(bool nullToAbsent) {
    return ChangesCompanion(
      id: Value(id),
      familyId: Value(familyId),
      entity: Value(entity),
      recordId: Value(recordId),
      field: Value(field),
      value: Value(value),
      hlc: Value(hlc),
      node: Value(node),
    );
  }

  factory ChangeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChangeRow(
      id: serializer.fromJson<String>(json['id']),
      familyId: serializer.fromJson<String>(json['familyId']),
      entity: serializer.fromJson<String>(json['entity']),
      recordId: serializer.fromJson<String>(json['recordId']),
      field: serializer.fromJson<String>(json['field']),
      value: serializer.fromJson<String>(json['value']),
      hlc: serializer.fromJson<String>(json['hlc']),
      node: serializer.fromJson<String>(json['node']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'familyId': serializer.toJson<String>(familyId),
      'entity': serializer.toJson<String>(entity),
      'recordId': serializer.toJson<String>(recordId),
      'field': serializer.toJson<String>(field),
      'value': serializer.toJson<String>(value),
      'hlc': serializer.toJson<String>(hlc),
      'node': serializer.toJson<String>(node),
    };
  }

  ChangeRow copyWith({
    String? id,
    String? familyId,
    String? entity,
    String? recordId,
    String? field,
    String? value,
    String? hlc,
    String? node,
  }) => ChangeRow(
    id: id ?? this.id,
    familyId: familyId ?? this.familyId,
    entity: entity ?? this.entity,
    recordId: recordId ?? this.recordId,
    field: field ?? this.field,
    value: value ?? this.value,
    hlc: hlc ?? this.hlc,
    node: node ?? this.node,
  );
  ChangeRow copyWithCompanion(ChangesCompanion data) {
    return ChangeRow(
      id: data.id.present ? data.id.value : this.id,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      entity: data.entity.present ? data.entity.value : this.entity,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      field: data.field.present ? data.field.value : this.field,
      value: data.value.present ? data.value.value : this.value,
      hlc: data.hlc.present ? data.hlc.value : this.hlc,
      node: data.node.present ? data.node.value : this.node,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChangeRow(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('hlc: $hlc, ')
          ..write('node: $node')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, familyId, entity, recordId, field, value, hlc, node);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChangeRow &&
          other.id == this.id &&
          other.familyId == this.familyId &&
          other.entity == this.entity &&
          other.recordId == this.recordId &&
          other.field == this.field &&
          other.value == this.value &&
          other.hlc == this.hlc &&
          other.node == this.node);
}

class ChangesCompanion extends UpdateCompanion<ChangeRow> {
  final Value<String> id;
  final Value<String> familyId;
  final Value<String> entity;
  final Value<String> recordId;
  final Value<String> field;
  final Value<String> value;
  final Value<String> hlc;
  final Value<String> node;
  final Value<int> rowid;
  const ChangesCompanion({
    this.id = const Value.absent(),
    this.familyId = const Value.absent(),
    this.entity = const Value.absent(),
    this.recordId = const Value.absent(),
    this.field = const Value.absent(),
    this.value = const Value.absent(),
    this.hlc = const Value.absent(),
    this.node = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChangesCompanion.insert({
    required String id,
    required String familyId,
    required String entity,
    required String recordId,
    required String field,
    required String value,
    required String hlc,
    required String node,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       familyId = Value(familyId),
       entity = Value(entity),
       recordId = Value(recordId),
       field = Value(field),
       value = Value(value),
       hlc = Value(hlc),
       node = Value(node);
  static Insertable<ChangeRow> custom({
    Expression<String>? id,
    Expression<String>? familyId,
    Expression<String>? entity,
    Expression<String>? recordId,
    Expression<String>? field,
    Expression<String>? value,
    Expression<String>? hlc,
    Expression<String>? node,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (familyId != null) 'family_id': familyId,
      if (entity != null) 'entity': entity,
      if (recordId != null) 'record_id': recordId,
      if (field != null) 'field': field,
      if (value != null) 'value': value,
      if (hlc != null) 'hlc': hlc,
      if (node != null) 'node': node,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChangesCompanion copyWith({
    Value<String>? id,
    Value<String>? familyId,
    Value<String>? entity,
    Value<String>? recordId,
    Value<String>? field,
    Value<String>? value,
    Value<String>? hlc,
    Value<String>? node,
    Value<int>? rowid,
  }) {
    return ChangesCompanion(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      entity: entity ?? this.entity,
      recordId: recordId ?? this.recordId,
      field: field ?? this.field,
      value: value ?? this.value,
      hlc: hlc ?? this.hlc,
      node: node ?? this.node,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (field.present) {
      map['field'] = Variable<String>(field.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (hlc.present) {
      map['hlc'] = Variable<String>(hlc.value);
    }
    if (node.present) {
      map['node'] = Variable<String>(node.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChangesCompanion(')
          ..write('id: $id, ')
          ..write('familyId: $familyId, ')
          ..write('entity: $entity, ')
          ..write('recordId: $recordId, ')
          ..write('field: $field, ')
          ..write('value: $value, ')
          ..write('hlc: $hlc, ')
          ..write('node: $node, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(key: Value(key), value: Value(value));
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) =>
      SettingRow(key: key ?? this.key, value: value ?? this.value);
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PeersTable extends Peers with TableInfo<$PeersTable, PeerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PeersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _familyIdMeta = const VerificationMeta(
    'familyId',
  );
  @override
  late final GeneratedColumn<String> familyId = GeneratedColumn<String>(
    'family_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transportMeta = const VerificationMeta(
    'transport',
  );
  @override
  late final GeneratedColumn<String> transport = GeneratedColumn<String>(
    'transport',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastSyncMeta = const VerificationMeta(
    'lastSync',
  );
  @override
  late final GeneratedColumn<int> lastSync = GeneratedColumn<int>(
    'last_sync',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    familyId,
    name,
    transport,
    lastSeen,
    lastSync,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'peers';
  @override
  VerificationContext validateIntegrity(
    Insertable<PeerRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('family_id')) {
      context.handle(
        _familyIdMeta,
        familyId.isAcceptableOrUnknown(data['family_id']!, _familyIdMeta),
      );
    } else if (isInserting) {
      context.missing(_familyIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('transport')) {
      context.handle(
        _transportMeta,
        transport.isAcceptableOrUnknown(data['transport']!, _transportMeta),
      );
    } else if (isInserting) {
      context.missing(_transportMeta);
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    } else if (isInserting) {
      context.missing(_lastSeenMeta);
    }
    if (data.containsKey('last_sync')) {
      context.handle(
        _lastSyncMeta,
        lastSync.isAcceptableOrUnknown(data['last_sync']!, _lastSyncMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId, familyId};
  @override
  PeerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PeerRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      familyId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}family_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      transport: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transport'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      )!,
      lastSync: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sync'],
      ),
    );
  }

  @override
  $PeersTable createAlias(String alias) {
    return $PeersTable(attachedDatabase, alias);
  }
}

class PeerRow extends DataClass implements Insertable<PeerRow> {
  final String deviceId;
  final String familyId;
  final String name;
  final String transport;
  final int lastSeen;
  final int? lastSync;
  const PeerRow({
    required this.deviceId,
    required this.familyId,
    required this.name,
    required this.transport,
    required this.lastSeen,
    this.lastSync,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['family_id'] = Variable<String>(familyId);
    map['name'] = Variable<String>(name);
    map['transport'] = Variable<String>(transport);
    map['last_seen'] = Variable<int>(lastSeen);
    if (!nullToAbsent || lastSync != null) {
      map['last_sync'] = Variable<int>(lastSync);
    }
    return map;
  }

  PeersCompanion toCompanion(bool nullToAbsent) {
    return PeersCompanion(
      deviceId: Value(deviceId),
      familyId: Value(familyId),
      name: Value(name),
      transport: Value(transport),
      lastSeen: Value(lastSeen),
      lastSync: lastSync == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSync),
    );
  }

  factory PeerRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PeerRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      familyId: serializer.fromJson<String>(json['familyId']),
      name: serializer.fromJson<String>(json['name']),
      transport: serializer.fromJson<String>(json['transport']),
      lastSeen: serializer.fromJson<int>(json['lastSeen']),
      lastSync: serializer.fromJson<int?>(json['lastSync']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'familyId': serializer.toJson<String>(familyId),
      'name': serializer.toJson<String>(name),
      'transport': serializer.toJson<String>(transport),
      'lastSeen': serializer.toJson<int>(lastSeen),
      'lastSync': serializer.toJson<int?>(lastSync),
    };
  }

  PeerRow copyWith({
    String? deviceId,
    String? familyId,
    String? name,
    String? transport,
    int? lastSeen,
    Value<int?> lastSync = const Value.absent(),
  }) => PeerRow(
    deviceId: deviceId ?? this.deviceId,
    familyId: familyId ?? this.familyId,
    name: name ?? this.name,
    transport: transport ?? this.transport,
    lastSeen: lastSeen ?? this.lastSeen,
    lastSync: lastSync.present ? lastSync.value : this.lastSync,
  );
  PeerRow copyWithCompanion(PeersCompanion data) {
    return PeerRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      familyId: data.familyId.present ? data.familyId.value : this.familyId,
      name: data.name.present ? data.name.value : this.name,
      transport: data.transport.present ? data.transport.value : this.transport,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
      lastSync: data.lastSync.present ? data.lastSync.value : this.lastSync,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PeerRow(')
          ..write('deviceId: $deviceId, ')
          ..write('familyId: $familyId, ')
          ..write('name: $name, ')
          ..write('transport: $transport, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSync: $lastSync')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, familyId, name, transport, lastSeen, lastSync);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PeerRow &&
          other.deviceId == this.deviceId &&
          other.familyId == this.familyId &&
          other.name == this.name &&
          other.transport == this.transport &&
          other.lastSeen == this.lastSeen &&
          other.lastSync == this.lastSync);
}

class PeersCompanion extends UpdateCompanion<PeerRow> {
  final Value<String> deviceId;
  final Value<String> familyId;
  final Value<String> name;
  final Value<String> transport;
  final Value<int> lastSeen;
  final Value<int?> lastSync;
  final Value<int> rowid;
  const PeersCompanion({
    this.deviceId = const Value.absent(),
    this.familyId = const Value.absent(),
    this.name = const Value.absent(),
    this.transport = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PeersCompanion.insert({
    required String deviceId,
    required String familyId,
    required String name,
    required String transport,
    required int lastSeen,
    this.lastSync = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       familyId = Value(familyId),
       name = Value(name),
       transport = Value(transport),
       lastSeen = Value(lastSeen);
  static Insertable<PeerRow> custom({
    Expression<String>? deviceId,
    Expression<String>? familyId,
    Expression<String>? name,
    Expression<String>? transport,
    Expression<int>? lastSeen,
    Expression<int>? lastSync,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (familyId != null) 'family_id': familyId,
      if (name != null) 'name': name,
      if (transport != null) 'transport': transport,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (lastSync != null) 'last_sync': lastSync,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PeersCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? familyId,
    Value<String>? name,
    Value<String>? transport,
    Value<int>? lastSeen,
    Value<int?>? lastSync,
    Value<int>? rowid,
  }) {
    return PeersCompanion(
      deviceId: deviceId ?? this.deviceId,
      familyId: familyId ?? this.familyId,
      name: name ?? this.name,
      transport: transport ?? this.transport,
      lastSeen: lastSeen ?? this.lastSeen,
      lastSync: lastSync ?? this.lastSync,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (familyId.present) {
      map['family_id'] = Variable<String>(familyId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (transport.present) {
      map['transport'] = Variable<String>(transport.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (lastSync.present) {
      map['last_sync'] = Variable<int>(lastSync.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PeersCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('familyId: $familyId, ')
          ..write('name: $name, ')
          ..write('transport: $transport, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('lastSync: $lastSync, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $ChangesTable changes = $ChangesTable(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $PeersTable peers = $PeersTable(this);
  late final Index changesFamilyNodeHlc = Index(
    'changes_family_node_hlc',
    'CREATE INDEX changes_family_node_hlc ON changes (family_id, node, hlc)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    records,
    changes,
    settings,
    peers,
    changesFamilyNodeHlc,
  ];
}

typedef $$RecordsTableCreateCompanionBuilder = RecordsCompanion Function({
  required String entity,
  required String id,
  required String familyId,
  required String data,
  required String clocks,
  Value<bool> deleted,
  required String updated,
  Value<int> rowid,
});
typedef $$RecordsTableUpdateCompanionBuilder = RecordsCompanion Function({
  Value<String> entity,
  Value<String> id,
  Value<String> familyId,
  Value<String> data,
  Value<String> clocks,
  Value<bool> deleted,
  Value<String> updated,
  Value<int> rowid,
});

class $$RecordsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clocks => $composableBuilder(
    column: $table.clocks,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clocks => $composableBuilder(
    column: $table.clocks,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updated => $composableBuilder(
    column: $table.updated,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<String> get clocks =>
      $composableBuilder(column: $table.clocks, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get updated =>
      $composableBuilder(column: $table.updated, builder: (column) => column);
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (RecordRow, BaseReferences<_$AppDatabase, $RecordsTable, RecordRow>),
          RecordRow,
          PrefetchHooks Function()
        > {
  $$RecordsTableTableManager(_$AppDatabase db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> entity = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<String> clocks = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<String> updated = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                entity: entity,
                id: id,
                familyId: familyId,
                data: data,
                clocks: clocks,
                deleted: deleted,
                updated: updated,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String entity,
                required String id,
                required String familyId,
                required String data,
                required String clocks,
                Value<bool> deleted = const Value.absent(),
                required String updated,
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                entity: entity,
                id: id,
                familyId: familyId,
                data: data,
                clocks: clocks,
                deleted: deleted,
                updated: updated,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecordsTable, RecordRow>(table),
                  BaseReferences<_$AppDatabase, $RecordsTable, RecordRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, BaseReferences<_$AppDatabase, $RecordsTable, RecordRow>),
      RecordRow,
      PrefetchHooks Function()
    >;
typedef $$ChangesTableCreateCompanionBuilder = ChangesCompanion Function({
  required String id,
  required String familyId,
  required String entity,
  required String recordId,
  required String field,
  required String value,
  required String hlc,
  required String node,
  Value<int> rowid,
});
typedef $$ChangesTableUpdateCompanionBuilder = ChangesCompanion Function({
  Value<String> id,
  Value<String> familyId,
  Value<String> entity,
  Value<String> recordId,
  Value<String> field,
  Value<String> value,
  Value<String> hlc,
  Value<String> node,
  Value<int> rowid,
});

class $$ChangesTableFilterComposer
    extends Composer<_$AppDatabase, $ChangesTable> {
  $$ChangesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get node => $composableBuilder(
    column: $table.node,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChangesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChangesTable> {
  $$ChangesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entity => $composableBuilder(
    column: $table.entity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get field => $composableBuilder(
    column: $table.field,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hlc => $composableBuilder(
    column: $table.hlc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get node => $composableBuilder(
    column: $table.node,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChangesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChangesTable> {
  $$ChangesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get field =>
      $composableBuilder(column: $table.field, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<String> get hlc =>
      $composableBuilder(column: $table.hlc, builder: (column) => column);

  GeneratedColumn<String> get node =>
      $composableBuilder(column: $table.node, builder: (column) => column);
}

class $$ChangesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChangesTable,
          ChangeRow,
          $$ChangesTableFilterComposer,
          $$ChangesTableOrderingComposer,
          $$ChangesTableAnnotationComposer,
          $$ChangesTableCreateCompanionBuilder,
          $$ChangesTableUpdateCompanionBuilder,
          (ChangeRow, BaseReferences<_$AppDatabase, $ChangesTable, ChangeRow>),
          ChangeRow,
          PrefetchHooks Function()
        > {
  $$ChangesTableTableManager(_$AppDatabase db, $ChangesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChangesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChangesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChangesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> entity = const Value.absent(),
                Value<String> recordId = const Value.absent(),
                Value<String> field = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<String> hlc = const Value.absent(),
                Value<String> node = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChangesCompanion(
                id: id,
                familyId: familyId,
                entity: entity,
                recordId: recordId,
                field: field,
                value: value,
                hlc: hlc,
                node: node,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String familyId,
                required String entity,
                required String recordId,
                required String field,
                required String value,
                required String hlc,
                required String node,
                Value<int> rowid = const Value.absent(),
              }) => ChangesCompanion.insert(
                id: id,
                familyId: familyId,
                entity: entity,
                recordId: recordId,
                field: field,
                value: value,
                hlc: hlc,
                node: node,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChangesTable, ChangeRow>(table),
                  BaseReferences<_$AppDatabase, $ChangesTable, ChangeRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChangesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChangesTable,
      ChangeRow,
      $$ChangesTableFilterComposer,
      $$ChangesTableOrderingComposer,
      $$ChangesTableAnnotationComposer,
      $$ChangesTableCreateCompanionBuilder,
      $$ChangesTableUpdateCompanionBuilder,
      (ChangeRow, BaseReferences<_$AppDatabase, $ChangesTable, ChangeRow>),
      ChangeRow,
      PrefetchHooks Function()
    >;
typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SettingsCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$PeersTableCreateCompanionBuilder = PeersCompanion Function({
  required String deviceId,
  required String familyId,
  required String name,
  required String transport,
  required int lastSeen,
  Value<int?> lastSync,
  Value<int> rowid,
});
typedef $$PeersTableUpdateCompanionBuilder = PeersCompanion Function({
  Value<String> deviceId,
  Value<String> familyId,
  Value<String> name,
  Value<String> transport,
  Value<int> lastSeen,
  Value<int?> lastSync,
  Value<int> rowid,
});

class $$PeersTableFilterComposer extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSync => $composableBuilder(
    column: $table.lastSync,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PeersTableOrderingComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get familyId => $composableBuilder(
    column: $table.familyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transport => $composableBuilder(
    column: $table.transport,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSync => $composableBuilder(
    column: $table.lastSync,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PeersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PeersTable> {
  $$PeersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get familyId =>
      $composableBuilder(column: $table.familyId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get transport =>
      $composableBuilder(column: $table.transport, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);

  GeneratedColumn<int> get lastSync =>
      $composableBuilder(column: $table.lastSync, builder: (column) => column);
}

class $$PeersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PeersTable,
          PeerRow,
          $$PeersTableFilterComposer,
          $$PeersTableOrderingComposer,
          $$PeersTableAnnotationComposer,
          $$PeersTableCreateCompanionBuilder,
          $$PeersTableUpdateCompanionBuilder,
          (PeerRow, BaseReferences<_$AppDatabase, $PeersTable, PeerRow>),
          PeerRow,
          PrefetchHooks Function()
        > {
  $$PeersTableTableManager(_$AppDatabase db, $PeersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PeersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PeersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PeersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> familyId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> transport = const Value.absent(),
                Value<int> lastSeen = const Value.absent(),
                Value<int?> lastSync = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion(
                deviceId: deviceId,
                familyId: familyId,
                name: name,
                transport: transport,
                lastSeen: lastSeen,
                lastSync: lastSync,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String familyId,
                required String name,
                required String transport,
                required int lastSeen,
                Value<int?> lastSync = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PeersCompanion.insert(
                deviceId: deviceId,
                familyId: familyId,
                name: name,
                transport: transport,
                lastSeen: lastSeen,
                lastSync: lastSync,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PeersTable, PeerRow>(table),
                  BaseReferences<_$AppDatabase, $PeersTable, PeerRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PeersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PeersTable,
      PeerRow,
      $$PeersTableFilterComposer,
      $$PeersTableOrderingComposer,
      $$PeersTableAnnotationComposer,
      $$PeersTableCreateCompanionBuilder,
      $$PeersTableUpdateCompanionBuilder,
      (PeerRow, BaseReferences<_$AppDatabase, $PeersTable, PeerRow>),
      PeerRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$ChangesTableTableManager get changes =>
      $$ChangesTableTableManager(_db, _db.changes);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$PeersTableTableManager get peers =>
      $$PeersTableTableManager(_db, _db.peers);
}
