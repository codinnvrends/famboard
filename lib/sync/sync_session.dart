import 'dart:async';
import 'dart:typed_data';

import '../data/record_store.dart';
import '../domain/change.dart';
import 'channel.dart';
import 'secure_channel.dart';

/// Outcome of one sync with one peer.
class SyncResult {
  const SyncResult({
    required this.familyId,
    required this.peerDeviceId,
    required this.peerName,
    required this.peerMemberId,
    required this.transport,
    required this.sent,
    required this.received,
  });

  final String familyId;
  final String peerDeviceId;
  final String peerName;
  final String peerMemberId;
  final String transport;
  final int sent;
  final int received;
}

/// Who this device is, for the handshake.
class LocalIdentity {
  const LocalIdentity({required this.deviceId, required this.deviceName});
  final String deviceId;
  final String deviceName;
}

/// Lets the session check membership: removed members are refused.
typedef MemberCheck = Future<bool> Function(String familyId, String memberId);

/// Resolves which member this device is in a family.
typedef MemberIdFor = Future<String?> Function(String familyId);

/// One sync exchange (spec section 7, "Exchange"):
///
/// 1. Secure handshake ([SecureChannel]).
/// 2. Both sides send `who` (member id) and `vv` (version vector).
/// 3. Each sends the changes the other lacks in size-capped batches, then
///    `end`.
/// 4. Each applies what it receives. Changes keep their origin, so data
///    relays through intermediate devices.
class SyncSession {
  SyncSession({
    required this.store,
    required this.identity,
    required this.memberIdFor,
    required this.isMemberAllowed,
  });

  final ChangeStore store;
  final LocalIdentity identity;
  final MemberIdFor memberIdFor;
  final MemberCheck isMemberAllowed;

  /// Runs as the connecting side for [familyId].
  Future<SyncResult> initiate({
    required PeerChannel channel,
    required String familyId,
    required Uint8List familyKey,
  }) async {
    final secure = await SecureChannel.initiate(
      channel: channel,
      familyId: familyId,
      familyKey: familyKey,
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
    );
    return _exchange(secure);
  }

  /// Runs as the accepting side.
  Future<SyncResult> accept({
    required PeerChannel channel,
    required Future<(String, Uint8List)?> Function(String tag) lookup,
  }) async {
    final secure = await SecureChannel.accept(
      channel: channel,
      lookup: lookup,
      deviceId: identity.deviceId,
      deviceName: identity.deviceName,
    );
    return _exchange(secure);
  }

  Future<SyncResult> _exchange(SecureChannel secure) async {
    final familyId = secure.familyId;
    try {
      final me = await memberIdFor(familyId) ?? '';
      await secure.send({
        't': 'who',
        'member': me,
        'vv': await store.versionVector(familyId),
      });
      final who = await _expect(secure, 'who');
      final peerMember = who['member'] as String? ?? '';
      if (peerMember.isEmpty || !await isMemberAllowed(familyId, peerMember)) {
        await secure.send({'t': 'bye', 'reason': 'not-a-member'});
        throw SyncAuthException('Device belongs to a removed member');
      }
      final peerVector = Map<String, String>.from(who['vv']! as Map);

      // Send what they lack.
      final outgoing = await store.changesSince(familyId, peerVector);
      final sendDone = _sendChanges(secure, outgoing);

      // Receive what we lack until they say `end`.
      var received = 0;
      while (true) {
        final msg = await secure.receive();
        switch (msg['t']) {
          case 'ch':
            final list = (msg['c']! as List)
                .map((e) => Change.fromWire(Map<String, Object?>.from(e! as Map)))
                .where((c) => c.familyId == familyId)
                .toList();
            received += await store.applyRemote(list);
          case 'end':
            await sendDone;
            await secure.send({'t': 'bye'});
            return SyncResult(
              familyId: familyId,
              peerDeviceId: secure.peer.deviceId,
              peerName: secure.peer.name,
              peerMemberId: peerMember,
              transport: secure.transport,
              sent: outgoing.length,
              received: received,
            );
          case 'bye':
            throw SyncProtocolException('Peer ended the sync: ${msg['reason']}');
          default:
            throw SyncProtocolException('Unexpected message ${msg['t']}');
        }
      }
    } finally {
      // Give the last frames a moment to flush before closing.
      unawaited(Future<void>.delayed(const Duration(milliseconds: 300), secure.close));
    }
  }

  Future<void> _sendChanges(SecureChannel secure, List<Change> changes) async {
    final limit = secure.maxMessageBytes - 512;
    var batch = <Map<String, Object?>>[];
    var size = 32;
    for (final c in changes) {
      final wire = c.toWire();
      final itemSize = SecureChannel.sealedSize(wire) + 1;
      if (batch.isNotEmpty && size + itemSize > limit) {
        await secure.send({'t': 'ch', 'c': batch});
        batch = [];
        size = 32;
      }
      batch.add(wire);
      size += itemSize;
    }
    if (batch.isNotEmpty) await secure.send({'t': 'ch', 'c': batch});
    await secure.send({'t': 'end', 'n': changes.length});
  }

  Future<Map<String, Object?>> _expect(SecureChannel secure, String type) async {
    final msg = await secure.receive();
    if (msg['t'] == 'bye') {
      throw SyncAuthException('Peer refused: ${msg['reason']}');
    }
    if (msg['t'] != type) throw SyncProtocolException('Expected $type, got ${msg['t']}');
    return msg;
  }
}
