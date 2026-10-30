import 'dart:async';
import 'dart:typed_data';

/// A message-oriented, ordered, reliable link to one peer. Transports (LAN
/// socket, Nearby Connections, in-memory for tests) all look like this to the
/// sync protocol.
abstract class PeerChannel {
  /// Short transport name shown to users: `wifi`, `nearby`, `memory`.
  String get transport;

  /// Largest message the transport carries in one piece.
  int get maxMessageBytes;

  Stream<Uint8List> get incoming;

  Future<void> send(Uint8List message);

  Future<void> close();
}

/// Two connected in-memory channels. Used by tests and by the sync
/// simulator.
class MemoryChannelPair {
  MemoryChannelPair({int maxMessageBytes = 32 * 1024}) {
    final ab = StreamController<Uint8List>();
    final ba = StreamController<Uint8List>();
    a = _MemoryChannel(ba.stream, ab, maxMessageBytes);
    b = _MemoryChannel(ab.stream, ba, maxMessageBytes);
  }

  late final PeerChannel a;
  late final PeerChannel b;
}

class _MemoryChannel implements PeerChannel {
  _MemoryChannel(this.incoming, this._out, this.maxMessageBytes);

  @override
  final Stream<Uint8List> incoming;
  final StreamController<Uint8List> _out;

  @override
  final int maxMessageBytes;

  @override
  String get transport => 'memory';

  @override
  Future<void> send(Uint8List message) async {
    if (message.length > maxMessageBytes) {
      throw ArgumentError('Message of ${message.length} bytes is too large');
    }
    if (!_out.isClosed) _out.add(Uint8List.fromList(message));
  }

  @override
  Future<void> close() async {
    if (!_out.isClosed) await _out.close();
  }
}

/// Splits a byte stream into length-prefixed messages (4-byte big-endian
/// length, then the payload). Used over TCP.
class LengthPrefixedFramer extends StreamTransformerBase<Uint8List, Uint8List> {
  const LengthPrefixedFramer({this.maxFrame = 8 * 1024 * 1024});

  final int maxFrame;

  static Uint8List frame(Uint8List payload) {
    final out = Uint8List(4 + payload.length);
    ByteData.view(out.buffer).setUint32(0, payload.length);
    out.setRange(4, out.length, payload);
    return out;
  }

  @override
  Stream<Uint8List> bind(Stream<Uint8List> stream) async* {
    final buffer = BytesBuilder(copy: false);
    var pending = Uint8List(0);
    await for (final chunk in stream) {
      buffer.add(pending);
      buffer.add(chunk);
      var data = buffer.takeBytes();
      var offset = 0;
      while (data.length - offset >= 4) {
        final len = ByteData.view(data.buffer, data.offsetInBytes + offset, 4).getUint32(0);
        if (len > maxFrame) {
          throw const FormatException('Frame too large');
        }
        if (data.length - offset - 4 < len) break;
        yield Uint8List.fromList(data.sublist(offset + 4, offset + 4 + len));
        offset += 4 + len;
      }
      pending = Uint8List.fromList(data.sublist(offset));
      data = Uint8List(0);
    }
  }
}
