import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:cryptography/cryptography.dart';

import 'channel.dart';

/// Raised when a peer fails the handshake or a frame fails to decrypt.
class SyncAuthException implements Exception {
  SyncAuthException(this.message);
  final String message;
  @override
  String toString() => 'SyncAuthException: $message';
}

/// The other phone isn't in the family this session asked about. Expected
/// when two phones share some families but not others.
class NotInFamilyException implements Exception {
  @override
  String toString() => 'Not in this family';
}

class SyncProtocolException implements Exception {
  SyncProtocolException(this.message);
  final String message;
  @override
  String toString() => 'SyncProtocolException: $message';
}

/// Public, non-secret label for a family: HMAC of the family key. Peers use it
/// to find a shared family without revealing the family id to strangers.
Future<String> familyTag(Uint8List familyKey) async {
  final mac = await Hmac.sha256().calculateMac(
    utf8.encode('famboard-family-tag-v1'),
    secretKey: SecretKey(familyKey),
  );
  return base64Url.encode(mac.bytes.sublist(0, 9));
}

/// What a peer said about itself in its hello.
class PeerHello {
  const PeerHello({required this.tag, required this.deviceId, required this.name});
  final String tag;
  final String deviceId;
  final String name;
}

/// An authenticated, encrypted message channel over a [PeerChannel].
///
/// Handshake:
/// 1. Each side sends a plaintext hello: family tag, device id, an ephemeral
///    X25519 public key and a random nonce.
/// 2. Both derive two ChaCha20-Poly1305 keys (one per direction) with HKDF
///    over the X25519 shared secret, salted with the family key and bound to
///    both hellos. Without the family key the derived keys are wrong and the
///    first encrypted frame fails to open.
/// 3. Each side sends an encrypted proof: HMAC(family key, transcript, role).
///
/// Ephemeral keys give each session fresh keys (forward secrecy).
class SecureChannel {
  SecureChannel._(
    this._channel,
    this._queue,
    this._sendKey,
    this._recvKey,
    this.peer,
    this.familyId,
  );

  final PeerChannel _channel;
  final StreamQueue<Uint8List> _queue;
  final SecretKey _sendKey;
  final SecretKey _recvKey;
  final PeerHello peer;
  final String familyId;
  int _sendCounter = 0;
  int _recvCounter = 0;

  static final _aead = Chacha20.poly1305Aead();
  static const _plain = 0x00;
  static const _sealed = 0x01;
  static const Duration timeout = Duration(seconds: 20);

  String get transport => _channel.transport;
  int get maxMessageBytes => _channel.maxMessageBytes - 64;

  /// Opens the session as the side that connected.
  static Future<SecureChannel> initiate({
    required PeerChannel channel,
    required String familyId,
    required Uint8List familyKey,
    required String deviceId,
    required String deviceName,
  }) async {
    final queue = StreamQueue(channel.incoming);
    final tag = await familyTag(familyKey);
    final eph = await X25519().newKeyPair();
    final myHello = await _hello(tag, deviceId, deviceName, eph);
    await channel.send(_wrapPlain(myHello));

    final (reply, replyBytes) = await _readPlain(queue);
    if (reply['t'] == 'reject') {
      if (reply['reason'] == 'family') throw NotInFamilyException();
      throw SyncAuthException('Peer rejected: ${reply['reason']}');
    }
    if (reply['t'] != 'hello' || reply['tag'] != tag) {
      throw SyncAuthException('Peer is not in this family');
    }
    return _finish(
      channel: channel,
      queue: queue,
      familyId: familyId,
      familyKey: familyKey,
      eph: eph,
      initiatorHello: myHello,
      responderHello: replyBytes,
      peerHello: reply,
      isInitiator: true,
    );
  }

  /// Opens the session as the side that accepted the connection.
  /// [lookup] maps a family tag to (familyId, familyKey) for families this
  /// device belongs to.
  static Future<SecureChannel> accept({
    required PeerChannel channel,
    required Future<(String, Uint8List)?> Function(String tag) lookup,
    required String deviceId,
    required String deviceName,
  }) async {
    final queue = StreamQueue(channel.incoming);
    final (hello, helloBytes) = await _readPlain(queue);
    if (hello['t'] != 'hello' || hello['v'] != 1) {
      throw SyncProtocolException('Expected hello');
    }
    final tag = hello['tag'] as String? ?? '';
    final family = await lookup(tag);
    if (family == null) {
      await channel.send(_wrapPlain(utf8.encode(jsonEncode({'t': 'reject', 'reason': 'family'}))));
      throw NotInFamilyException();
    }
    final eph = await X25519().newKeyPair();
    final myHello = await _hello(tag, deviceId, deviceName, eph);
    await channel.send(_wrapPlain(myHello));
    return _finish(
      channel: channel,
      queue: queue,
      familyId: family.$1,
      familyKey: family.$2,
      eph: eph,
      initiatorHello: helloBytes,
      responderHello: myHello,
      peerHello: hello,
      isInitiator: false,
    );
  }

  static Future<SecureChannel> _finish({
    required PeerChannel channel,
    required StreamQueue<Uint8List> queue,
    required String familyId,
    required Uint8List familyKey,
    required SimpleKeyPair eph,
    required List<int> initiatorHello,
    required List<int> responderHello,
    required Map<String, Object?> peerHello,
    required bool isInitiator,
  }) async {
    final peerPub = base64Decode(peerHello['eph'] as String? ?? '');
    if (peerPub.length != 32) throw SyncProtocolException('Bad public key');
    final shared = await X25519().sharedSecretKey(
      keyPair: eph,
      remotePublicKey: SimplePublicKey(peerPub, type: KeyPairType.x25519),
    );
    final transcript = (await Sha256().hash([...initiatorHello, ...responderHello])).bytes;
    final derived = await Hkdf(hmac: Hmac.sha256(), outputLength: 64).deriveKey(
      secretKey: shared,
      nonce: familyKey,
      info: [...utf8.encode('famboard-sync-v1'), ...transcript],
    );
    final bytes = await derived.extractBytes();
    final i2r = SecretKey(bytes.sublist(0, 32));
    final r2i = SecretKey(bytes.sublist(32, 64));
    final secure = SecureChannel._(
      channel,
      queue,
      isInitiator ? i2r : r2i,
      isInitiator ? r2i : i2r,
      PeerHello(
        tag: peerHello['tag'] as String? ?? '',
        deviceId: peerHello['dev'] as String? ?? '',
        name: peerHello['name'] as String? ?? '',
      ),
      familyId,
    );

    final proofKey = SecretKey(familyKey);
    Future<String> proof(String role) async => base64Encode(
          (await Hmac.sha256().calculateMac(
            [...transcript, ...utf8.encode(role)],
            secretKey: proofKey,
          ))
              .bytes,
        );
    await secure.send({'t': 'auth', 'mac': await proof(isInitiator ? 'I' : 'R')});
    final Map<String, Object?> auth;
    try {
      auth = await secure.receive();
    } on SecretBoxAuthenticationError {
      throw SyncAuthException('Peer does not hold the family key');
    }
    if (auth['t'] != 'auth' || auth['mac'] != await proof(isInitiator ? 'R' : 'I')) {
      throw SyncAuthException('Peer failed authentication');
    }
    return secure;
  }

  static Future<List<int>> _hello(
    String tag,
    String deviceId,
    String deviceName,
    SimpleKeyPair eph,
  ) async {
    final pub = await eph.extractPublicKey();
    final nonce = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    return utf8.encode(jsonEncode({
      't': 'hello',
      'v': 1,
      'tag': tag,
      'dev': deviceId,
      'name': deviceName,
      'eph': base64Encode(pub.bytes),
      'n': base64Encode(nonce),
    }));
  }

  static Uint8List _wrapPlain(List<int> json) =>
      Uint8List.fromList([_plain, ...json]);

  static Future<(Map<String, Object?>, List<int>)> _readPlain(
    StreamQueue<Uint8List> queue,
  ) async {
    if (!await queue.hasNext.timeout(timeout)) {
      throw SyncProtocolException('Peer closed during handshake');
    }
    final msg = await queue.next;
    if (msg.isEmpty || msg[0] != _plain) throw SyncProtocolException('Expected plaintext');
    final raw = msg.sublist(1);
    return (Map<String, Object?>.from(jsonDecode(utf8.decode(raw)) as Map), raw);
  }

  static List<int> _nonce(int counter) {
    final n = Uint8List(12);
    ByteData.view(n.buffer).setUint64(4, counter);
    return n;
  }

  Future<void> send(Map<String, Object?> message) async {
    final clear = utf8.encode(jsonEncode(message));
    final box = await _aead.encrypt(
      clear,
      secretKey: _sendKey,
      nonce: _nonce(_sendCounter++),
    );
    await _channel.send(Uint8List.fromList([_sealed, ...box.cipherText, ...box.mac.bytes]));
  }

  /// Encoded size of [message] once sealed; used to keep batches under the
  /// transport's message limit.
  static int sealedSize(Map<String, Object?> message) =>
      utf8.encode(jsonEncode(message)).length + 17;

  Future<Map<String, Object?>> receive() async {
    if (!await _queue.hasNext.timeout(timeout)) {
      throw SyncProtocolException('Peer closed the connection');
    }
    final msg = await _queue.next;
    if (msg.length < 17 || msg[0] != _sealed) {
      throw SyncProtocolException('Expected encrypted frame');
    }
    final cipher = msg.sublist(1, msg.length - 16);
    final mac = Mac(msg.sublist(msg.length - 16));
    final clear = await _aead.decrypt(
      SecretBox(cipher, nonce: _nonce(_recvCounter++), mac: mac),
      secretKey: _recvKey,
    );
    return Map<String, Object?>.from(jsonDecode(utf8.decode(clear)) as Map);
  }

  Future<void> close() async {
    await _channel.close();
    await _queue.cancel(immediate: true);
  }
}
