import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../data/blob_store.dart';
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
    this.photosReceived = 0,
  });

  final String familyId;
  final String peerDeviceId;
  final String peerName;
  final String peerMemberId;
  final String transport;
  final int sent;
  final int received;
  final int photosReceived;
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
    this.blobs,
  });

  /// Capability flag for the photo exchange. Older app versions don't send
  /// it, so they never see the extra messages.
  static const capBlobs = 'blobs1';

  /// Photos only travel over Wi‑Fi; over Bluetooth just the details sync and
  /// photos follow the next time both phones share a Wi‑Fi network.
  static const blobTransports = {'wifi', 'memory'};

  final ChangeStore store;
  final BlobSource? blobs;
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
        if (blobs != null) 'caps': [capBlobs],
      });
      final who = await _expect(secure, 'who');
      final peerMember = who['member'] as String? ?? '';
      if (peerMember.isEmpty || !await isMemberAllowed(familyId, peerMember)) {
        await secure.send({'t': 'bye', 'reason': 'not-a-member'});
        throw SyncAuthException('Device belongs to a removed member');
      }
      final peerVector = Map<String, String>.from(who['vv']! as Map);
      final peerCaps = {...((who['caps'] as List?) ?? const []).whereType<String>()};

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
            var photos = 0;
            final source = blobs;
            if (source != null &&
                peerCaps.contains(capBlobs) &&
                blobTransports.contains(secure.transport)) {
              photos = await _swapBlobs(secure, familyId, source);
            }
            await secure.send({'t': 'bye'});
            return SyncResult(
              familyId: familyId,
              peerDeviceId: secure.peer.deviceId,
              peerName: secure.peer.name,
              peerMemberId: peerMember,
              transport: secure.transport,
              sent: outgoing.length,
              received: received,
              photosReceived: photos,
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

  /// Photo exchange, after both sides have all records: each asks for the
  /// photos its records point at but it lacks, answers the other's request,
  /// then sends `bend`. Returns how many photos arrived.
  Future<int> _swapBlobs(SecureChannel secure, String familyId, BlobSource source) async {
    await secure.send({'t': 'want', 'ids': await source.missingBlobs(familyId)});
    Future<void>? answering;
    var peerDone = false;
    var got = 0;
    while (!peerDone || answering == null) {
      final msg = await secure.receive();
      switch (msg['t']) {
        case 'want':
          final ids = ((msg['ids'] as List?) ?? const []).whereType<String>().toList();
          answering = _sendBlobs(secure, familyId, source, ids);
        case 'blob':
          final id = msg['id'] as String? ?? '';
          final data = msg['b'] as String? ?? '';
          if (id.isNotEmpty && data.isNotEmpty) {
            final ok = await source.putVerified(
              familyId,
              id,
              base64Decode(data),
              mime: msg['m'] as String? ?? 'image/jpeg',
            );
            if (ok) got++;
          }
        case 'bend':
          peerDone = true;
        case 'bye':
          throw SyncProtocolException('Peer ended the sync: ${msg['reason']}');
        default:
          throw SyncProtocolException('Unexpected message ${msg['t']}');
      }
    }
    await answering;
    return got;
  }

  Future<void> _sendBlobs(
    SecureChannel secure,
    String familyId,
    BlobSource source,
    List<String> ids,
  ) async {
    final limit = secure.maxMessageBytes - 512;
    for (final id in ids) {
      final bytes = await source.blob(familyId, id);
      if (bytes == null) continue;
      final msg = {'t': 'blob', 'id': id, 'm': 'image/jpeg', 'b': base64Encode(bytes)};
      // Too big for this transport: skip it rather than fail the sync.
      if (SecureChannel.sealedSize(msg) > limit) continue;
      await secure.send(msg);
    }
    await secure.send({'t': 'bend'});
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
