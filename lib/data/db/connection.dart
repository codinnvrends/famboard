import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

import 'database.dart';

/// Opens the app database encrypted with SQLite3MultipleCiphers.
///
/// [hexKey] is a 32-byte random key held in the platform keystore.
AppDatabase openEncryptedDatabase(File file, String hexKey) {
  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) {
        db.execute("PRAGMA hexkey = '$hexKey';");
        // Fails fast if the key is wrong or the library lacks encryption.
        db.select('SELECT count(*) FROM sqlite_master;');
      },
    ),
  );
}

/// In-memory database for tests and previews.
AppDatabase openMemoryDatabase() =>
    AppDatabase(NativeDatabase.memory(logStatements: false));

/// Wraps an arbitrary executor (used by tests that share one connection).
AppDatabase openWith(QueryExecutor executor) => AppDatabase(executor);
