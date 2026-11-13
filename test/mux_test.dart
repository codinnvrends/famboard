import 'dart:convert';
import 'dart:typed_data';

import 'package:famboard/sync/channel.dart';
import 'package:famboard/sync/mux.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Uint8List b(String s) => Uint8List.fromList(utf8.encode(s));

  test('both sides can open streams at once without clashing', () async {
    final pair = MemoryChannelPair();
    final fromA = <String>[];
    final fromB = <String>[];
    // Both believe they dialled; ids are split by device id instead.
    final a = MuxConnection(pair.a, localId: 'aaaa', onStream: (s) => s.incoming.listen((m) => fromA.add(utf8.decode(m))));
    final c = MuxConnection(pair.b, localId: 'bbbb', onStream: (s) => s.incoming.listen((m) => fromB.add(utf8.decode(m))));
    expect(await a.peerId, 'bbbb');
    expect(await c.peerId, 'aaaa');

    final a1 = await a.open();
    final a2 = await a.open();
    final c1 = await c.open();
    await a1.send(b('family-1 from A'));
    await a2.send(b('family-2 from A'));
    await c1.send(b('family-3 from B'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(fromB, ['family-1 from A', 'family-2 from A']);
    expect(fromA, ['family-3 from B']);
  });

  test('closing one session keeps the connection for the next', () async {
    final pair = MemoryChannelPair();
    final got = <String>[];
    final a = MuxConnection(pair.a, localId: 'a');
    MuxConnection(pair.b, localId: 'b', onStream: (s) => s.incoming.listen((m) => got.add(utf8.decode(m))));
    final s1 = await a.open();
    await s1.send(b('one'));
    await s1.close();
    final s2 = await a.open();
    await s2.send(b('two'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(got, ['one', 'two']);
    expect(a.isClosed, isFalse);
  });

  test('an older FamBoard on the other end is reported', () async {
    final pair = MemoryChannelPair();
    Object? error;
    final a = MuxConnection(pair.a, localId: 'a', onError: (e) => error = e);
    await pair.b.send(Uint8List.fromList([0x00, 1, 2, 3])); // old plaintext hello
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(error, isA<IncompatiblePeerException>());
    expect(a.isClosed, isTrue);
  });
}
