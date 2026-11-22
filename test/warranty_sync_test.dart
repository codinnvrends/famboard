import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/data/blob_store.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/data/record_store.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/sync/channel.dart';
import 'package:famboard/sync/secure_channel.dart';
import 'package:famboard/sync/sync_session.dart';
import 'package:flutter_test/flutter_test.dart';

/// Wraps a channel to pretend it runs over another transport.
class _As implements PeerChannel {
  _As(this.inner, this.transport);
  final PeerChannel inner;
  @override
  final String transport;
  @override
  int get maxMessageBytes => inner.maxMessageBytes;
  @override
  Stream<Uint8List> get incoming => inner.incoming;
  @override
  Future<void> send(Uint8List message) => inner.send(message);
  @override
  Future<void> close() => inner.close();
}

class _Phone {
  _Phone(this.store, this.blobs, this.id, {this.photos = true});
  final RecordStore store;
  final BlobStore blobs;
  final String id;

  /// False = an older app version without the photo exchange.
  final bool photos;

  SyncSession session() => SyncSession(
        store: store,
        blobs: photos ? blobs : null,
        identity: LocalIdentity(deviceId: id, deviceName: 'Phone $id'),
        memberIdFor: (_) async => 'm$id',
        isMemberAllowed: (_, _) async => true,
      );
}

Future<_Phone> _phone(String id, {bool photos = true}) async {
  final db = openMemoryDatabase();
  final store = await RecordStore.open(db, id);
  return _Phone(store, BlobStore(db, store), id, photos: photos);
}

Future<(SyncResult, SyncResult)> _sync(
  _Phone a,
  _Phone b, {
  String transport = 'wifi',
  int maxMessageBytes = 1024 * 1024,
}) async {
  final key = _key;
  final pair = MemoryChannelPair(maxMessageBytes: maxMessageBytes);
  final tag = await familyTag(key);
  final r = await Future.wait([
    a.session().initiate(channel: _As(pair.a, transport), familyId: 'fam', familyKey: key),
    b.session().accept(channel: _As(pair.b, transport), lookup: (t) async => t == tag ? ('fam', key) : null),
  ]);
  return (r[0], r[1]);
}

final _key = KeyVault.randomKey();

Uint8List _photo(int size, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(size, (_) => r.nextInt(256)));
}

/// Adds an appliance on [p] with one photo; returns the photo id.
Future<String> _addAppliance(_Phone p, String id, Uint8List photo) async {
  final photoId = await p.blobs.put('fam', photo);
  await p.store.write(RecordWrite(
    familyId: 'fam',
    entity: Entities.appliance,
    id: id,
    fields: {'name': 'Fridge $id', 'photos': [photoId]},
  ));
  return photoId;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a warranty photo follows its record to the other phone over Wi-Fi', () async {
    final a = await _phone('A');
    final b = await _phone('B');
    final bytes = _photo(300 * 1024, 1);
    final id = await _addAppliance(a, 'x1', bytes);

    final (ra, rb) = await _sync(a, b);
    expect(rb.received, greaterThan(0));
    expect(rb.photosReceived, 1);
    expect(ra.photosReceived, 0);
    expect(await b.blobs.blob('fam', id), bytes);
    expect(await b.blobs.missingBlobs('fam'), isEmpty);

    // Nothing to send the second time.
    final (again, againB) = await _sync(a, b);
    expect(again.photosReceived + againB.photosReceived, 0);
  });

  test('photos flow both ways in one sync', () async {
    final a = await _phone('A');
    final b = await _phone('B');
    final pa = await _addAppliance(a, 'x1', _photo(50 * 1024, 1));
    final pb = await _addAppliance(b, 'x2', _photo(60 * 1024, 2));
    final (ra, rb) = await _sync(a, b);
    expect(ra.photosReceived, 1);
    expect(rb.photosReceived, 1);
    expect(await a.blobs.has('fam', pb), isTrue);
    expect(await b.blobs.has('fam', pa), isTrue);
  });

  test('photos relay through a phone that has them', () async {
    final a = await _phone('A');
    final b = await _phone('B');
    final c = await _phone('C');
    final id = await _addAppliance(a, 'x1', _photo(40 * 1024, 3));
    await _sync(a, b);
    final (_, rc) = await _sync(b, c);
    expect(rc.photosReceived, 1);
    expect(await c.blobs.has('fam', id), isTrue);
  });

  test('over Bluetooth only the details sync; photos wait for Wi-Fi', () async {
    final a = await _phone('A');
    final b = await _phone('B');
    final id = await _addAppliance(a, 'x1', _photo(20 * 1024, 4));

    final (_, rb) = await _sync(a, b, transport: 'nearby', maxMessageBytes: 32 * 1024);
    expect(rb.received, greaterThan(0));
    expect(rb.photosReceived, 0);
    expect(await b.blobs.missingBlobs('fam'), [id]);

    final (_, later) = await _sync(a, b);
    expect(later.photosReceived, 1);
    expect(await b.blobs.missingBlobs('fam'), isEmpty);
  });

  test('an older app version still syncs records with a new one', () async {
    final a = await _phone('A');
    final old = await _phone('B', photos: false);
    await _addAppliance(a, 'x1', _photo(10 * 1024, 5));
    await old.store.write(const RecordWrite(
      familyId: 'fam', entity: Entities.entry, id: 'e1', fields: {'title': 'Milk', 'type': 'need_to_buy'},
    ));

    final (ra, rb) = await _sync(a, old);
    expect(ra.received, greaterThan(0));
    expect(rb.received, greaterThan(0));
    expect(rb.photosReceived, 0);
    expect((await old.store.get(Entities.appliance, 'x1'))!.fields['name'], 'Fridge x1');
  });

  test('a photo too big for the link is skipped without failing the sync', () async {
    final a = await _phone('A');
    final b = await _phone('B');
    await _addAppliance(a, 'x1', _photo(64 * 1024, 6));
    final small = await _addAppliance(a, 'x2', _photo(4 * 1024, 7));

    final (_, rb) = await _sync(a, b, maxMessageBytes: 32 * 1024);
    expect(rb.photosReceived, 1);
    expect(await b.blobs.has('fam', small), isTrue);
    expect((await b.blobs.missingBlobs('fam')).length, 1);
  });

  test('a photo that does not match its id is refused', () async {
    final p = await _phone('A');
    final real = _photo(1000, 8);
    final id = await BlobStore.hashOf(real);
    expect(await p.blobs.putVerified('fam', id, _photo(1000, 9)), isFalse);
    expect(await p.blobs.has('fam', id), isFalse);
    expect(await p.blobs.putVerified('fam', id, real), isTrue);
  });

  test('sweep drops photos nothing points at, after a grace day', () async {
    final p = await _phone('A');
    final kept = await _addAppliance(p, 'x1', _photo(1000, 10));
    final orphan = await p.blobs.put('fam', _photo(1000, 11));
    // Fresh orphans survive (their record may still be on its way).
    expect(await p.blobs.sweep('fam'), 0);
    await p.blobs.db.customStatement('UPDATE blobs SET created = 0');
    expect(await p.blobs.sweep('fam'), 1);
    expect(await p.blobs.has('fam', kept), isTrue);
    expect(await p.blobs.has('fam', orphan), isFalse);
  });
}
