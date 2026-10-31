import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'channel.dart';

/// Thrown when the other phone speaks an older sync format.
class IncompatiblePeerException implements Exception {
  @override
  String toString() => 'The other phone runs an older FamBoard. Update both phones.';
}

/// Carries several independent sessions (one per family) over a single
/// connection between two phones.
///
/// Nearby Connections allows one connection per pair of phones, and
/// reconnecting takes seconds, so each family's encrypted session runs on
/// its own numbered stream inside one shared connection instead.
///
/// Wire format: `[0xF1][stream id, 4 bytes big-endian][payload]`. Stream 0
/// carries each side's device id, sent first. Both phones may dial at the
/// same time over Bluetooth and each believe it dialled, so stream ids are
/// split by device id instead: the lower id opens odd streams, the higher
/// even ones.
class MuxConnection {
  MuxConnection(
    this.base, {
    required this.localId,
    void Function(PeerChannel stream)? onStream,
    void Function(Object error)? onError,
    this.idleTimeout = const Duration(minutes: 2),
  })  : _onStream = onStream, // ignore: prefer_initializing_formals
        _onError = onError { // ignore: prefer_initializing_formals
    _sub = base.incoming.listen(
      _onMessage,
      onError: (Object e) {
        _onError?.call(e);
        close();
      },
      onDone: close,
    );
    unawaited(_send(0, Uint8List.fromList(utf8.encode(localId))).catchError((Object e) {
      _onError?.call(e);
      close();
    }));
    // Nobody may be waiting when the connection fails; don't report it twice.
    _peer.future.ignore();
    _touch();
  }

  final String localId;
  final _peer = Completer<String>();

  /// The other phone's device id, once it has introduced itself.
  Future<String> get peerId => _peer.future;

  static const _marker = 0xF1;
  static const _header = 5;

  final PeerChannel base;
  final Duration idleTimeout;
  final void Function(PeerChannel stream)? _onStream;
  final void Function(Object error)? _onError;
  late final StreamSubscription<Uint8List> _sub;
  final Map<int, _MuxStream> _streams = {};
  final Set<int> _finished = {};
  int _nextId = 0;
  bool _closed = false;
  Timer? _idle;
  final _done = Completer<void>();

  bool get isClosed => _closed;
  String get transport => base.transport;

  /// Completes when the connection closes.
  Future<void> get done => _done.future;

  /// Opens a new stream (for one family's session).
  Future<PeerChannel> open() async {
    await peerId.timeout(const Duration(seconds: 15));
    if (_closed) throw StateError('Connection closed');
    final id = _nextId;
    _nextId += 2;
    return _streams[id] = _MuxStream(this, id);
  }

  void _onMessage(Uint8List message) {
    _touch();
    if (message.length < _header || message[0] != _marker) {
      _onError?.call(IncompatiblePeerException());
      close();
      return;
    }
    final id = ByteData.view(message.buffer, message.offsetInBytes + 1, 4).getUint32(0);
    final payload = Uint8List.sublistView(message, _header);
    if (id == 0) {
      if (_peer.isCompleted) return;
      final peer = utf8.decode(payload, allowMalformed: true);
      _nextId = localId.compareTo(peer) < 0 ? 1 : 2;
      _peer.complete(peer);
      return;
    }
    if (!_peer.isCompleted) return;
    var stream = _streams[id];
    if (stream == null) {
      final opensRemote = id.isOdd != _nextId.isOdd;
      if (!opensRemote || _finished.contains(id)) return; // late frame for a finished session
      stream = _streams[id] = _MuxStream(this, id);
      _onStream?.call(stream);
    }
    stream._deliver(payload);
  }

  Future<void> _send(int id, Uint8List payload) async {
    if (_closed) throw StateError('Connection closed');
    _touch();
    final frame = Uint8List(_header + payload.length)
      ..[0] = _marker
      ..setRange(_header, _header + payload.length, payload);
    ByteData.view(frame.buffer, 1, 4).setUint32(0, id);
    await base.send(frame);
  }

  void _release(int id) {
    _streams.remove(id);
    _finished.add(id);
    _touch();
  }

  void _touch() {
    _idle?.cancel();
    if (!_closed) {
      _idle = Timer(idleTimeout, () {
        if (_streams.isEmpty) close();
      });
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _idle?.cancel();
    for (final s in _streams.values.toList()) {
      s._end();
    }
    _streams.clear();
    await _sub.cancel();
    try {
      await base.close();
    } catch (_) {}
    if (!_peer.isCompleted) _peer.completeError(StateError('Connection closed'));
    if (!_done.isCompleted) _done.complete();
  }
}

class _MuxStream implements PeerChannel {
  _MuxStream(this._mux, this.id);

  final MuxConnection _mux;
  final int id;
  final _incoming = StreamController<Uint8List>();
  bool _ended = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  String get transport => _mux.transport;

  @override
  int get maxMessageBytes => _mux.base.maxMessageBytes - MuxConnection._header;

  void _deliver(Uint8List bytes) {
    if (!_ended) _incoming.add(bytes);
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    unawaited(_incoming.close());
  }

  @override
  Future<void> send(Uint8List message) => _mux._send(id, message);

  /// Ends this session only; the shared connection stays open.
  @override
  Future<void> close() async {
    _end();
    _mux._release(id);
  }
}
