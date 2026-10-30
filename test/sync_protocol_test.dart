import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/data/record_store.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/sync/channel.dart';
import 'package:famboard/sync/secure_channel.dart';
import 'package:famboard/sync/sync_session.dart';
import 'package:flutter_test/flutter_test.dart';

class _Device {
  _Device(this.store, this.id, this.member, {this.removed = const {}});
  final RecordStore store;
  final String id;
  final String member;
  final Set<String> removed;

  SyncSession session() => SyncSession(
        store: store,
        identity: LocalIdentity(deviceId: id, deviceName: 'Phone $id'),
        memberIdFor: (_) async => member,
        isMemberAllowed: (_, m) async => !removed.contains(m),
      );
}

Future<_Device> _device(String id, String member, {Set<String> removed = const {}}) async =>
    _Device(await RecordStore.open(openMemoryDatabase(), id), id, member, removed: removed);

Future<(SyncResult, SyncResult)> _sync(
  _Device a,
  _Device b,
  Uint8List keyA,
  Uint8List keyB, {
  int maxMessageBytes = 32 * 1024,
}) async {
  final pair = MemoryChannelPair(maxMessageBytes: maxMessageBytes);
  final tagB = await familyTag(keyB);
  final results = await Future.wait([
    a.session().initiate(channel: pair.a, familyId: 'fam', familyKey: keyA),
    b.session().accept(
      channel: pair.b,
      lookup: (tag) async => tag == tagB ? ('fam', keyB) : null,
    ),
  ]);
  return (results[0], results[1]);
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final key = KeyVault.randomKey();

  test('two phones exchange only what the other lacks', () async {
    final a = await _device('A', 'mA');
    final b = await _device('B', 'mB');
    await a.store.write(const RecordWrite(
      familyId: 'fam', entity: Entities.entry, id: 'e1',
      fields: {'title': 'Milk', 'type': 'need_to_buy'},
    ));
    await b.store.write(const RecordWrite(
      familyId: 'fam', entity: Entities.entry, id: 'e2',
      fields: {'title': 'Fan not working', 'type': 'repair'},
    ));

    final (ra, rb) = await _sync(a, b, key, key);
    expect(ra.sent, 2);
    expect(ra.received, 2);
    expect(rb.peerName, 'Phone A');
    expect(rb.peerMemberId, 'mA');
    expect((await b.store.get(Entities.entry, 'e1'))!.fields['title'], 'Milk');
    expect((await a.store.get(Entities.entry, 'e2'))!.fields['title'], 'Fan not working');

    final (again, _) = await _sync(a, b, key, key);
    expect(again.sent, 0);
    expect(again.received, 0);
  });

  test('a device without the family key is refused', () async {
    final a = await _device('A', 'mA');
    final b = await _device('B', 'mB');
    final wrong = KeyVault.randomKey();
    await expectLater(_sync(a, b, wrong, key), throwsA(isA<SyncAuthException>()));
  });

  test('an impostor that knows the tag but not the key fails to authenticate', () async {
    final a = await _device('A', 'mA');
    final b = await _device('B', 'mB');
    final pair = MemoryChannelPair();
    final tag = await familyTag(key);
    final impostorKey = KeyVault.randomKey();
    final results = Future.wait([
      a.session().initiate(channel: pair.a, familyId: 'fam', familyKey: impostorKey),
      // B accepts any tag lookup as the real family, so the only defence left
      // is the key-dependent handshake.
      b.session().accept(channel: pair.b, lookup: (_) async => ('fam', key)),
    ], eagerError: true);
    expect(tag, isNotEmpty);
    await expectLater(results, throwsA(anything));
  });

  test('a removed member is refused', () async {
    final a = await _device('A', 'mA');
    final b = await _device('B', 'mB', removed: {'mA'});
    await a.store.write(const RecordWrite(
      familyId: 'fam', entity: Entities.entry, id: 'e1', fields: {'title': 'x'},
    ));
    await expectLater(_sync(a, b, key, key), throwsA(anything));
    expect(await b.store.get(Entities.entry, 'e1'), isNull);
  });

  test('large backlogs are split to fit small transport messages', () async {
    final a = await _device('A', 'mA');
    final b = await _device('B', 'mB');
    await a.store.writeAll([
      for (var i = 0; i < 400; i++)
        RecordWrite(
          familyId: 'fam', entity: Entities.entry, id: 'e$i',
          fields: {'title': 'Item number $i with a longer title', 'note': 'x' * 40},
        ),
    ]);
    final (ra, _) = await _sync(a, b, key, key, maxMessageBytes: 4096);
    expect(ra.sent, 800);
    expect((await b.store.list('fam', Entities.entry)).length, 400);
  });

  test('length-prefixed framing reassembles split TCP chunks', () async {
    final frames = [
      Uint8List.fromList([1, 2, 3]),
      Uint8List.fromList(List.filled(1000, 7)),
      Uint8List(0),
    ];
    final bytes = frames.expand(LengthPrefixedFramer.frame).toList();
    final chunks = <Uint8List>[];
    for (var i = 0; i < bytes.length; i += 5) {
      chunks.add(Uint8List.fromList(bytes.sublist(i, i + 5 > bytes.length ? bytes.length : i + 5)));
    }
    final out = await Stream.fromIterable(chunks).transform(const LengthPrefixedFramer()).toList();
    expect(out.map((f) => f.length), [3, 1000, 0]);
  });
}
