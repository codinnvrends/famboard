import 'package:drift/drift.dart';

part 'database.g.dart';

/// Merged state of every synced record, one row per (entity, id).
@DataClassName('RecordRow')
class Records extends Table {
  TextColumn get entity => text()();
  TextColumn get id => text()();
  TextColumn get familyId => text()();

  /// JSON object: field → value.
  TextColumn get data => text()();

  /// JSON object: field → HLC of the change that set it.
  TextColumn get clocks => text()();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// Highest clock across fields; orders "recently changed".
  TextColumn get updated => text()();

  @override
  Set<Column<Object>> get primaryKey => {entity, id};
}

/// Append-only log of field changes; what peers exchange.
@DataClassName('ChangeRow')
@TableIndex(name: 'changes_family_node_hlc', columns: {#familyId, #node, #hlc})
class Changes extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get field => text()();

  /// JSON-encoded value.
  TextColumn get value => text()();
  TextColumn get hlc => text()();
  TextColumn get node => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Device-local settings. Never synced.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Family devices this phone has seen. Never synced.
@DataClassName('PeerRow')
class Peers extends Table {
  TextColumn get deviceId => text()();
  TextColumn get familyId => text()();
  TextColumn get name => text()();
  TextColumn get transport => text()();
  IntColumn get lastSeen => integer()();
  IntColumn get lastSync => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {deviceId, familyId};
}

@DriftDatabase(tables: [Records, Changes, Settings, Peers])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await customStatement(
            'CREATE INDEX IF NOT EXISTS records_family_entity '
            'ON records (family_id, entity)',
          );
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
