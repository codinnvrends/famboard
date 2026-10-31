import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';

import 'channel.dart';
import 'transport.dart';

/// No-Wi‑Fi sync on Android through Google Nearby Connections, which picks
/// Bluetooth, BLE or Wi‑Fi Direct by itself.
///
/// Nearby's own connection step accepts everyone; the real check is the
/// family-key handshake that runs over the channel straight after.
class NearbyTransport implements SyncTransport {
  NearbyTransport({Nearby? nearby}) : _nearby = nearby ?? Nearby();

  static const serviceId = 'com.famboard.app';

  /// Nearby's limit for a bytes payload is 32 KB; leave headroom.
  static const maxPayload = 30 * 1024;

  final Nearby _nearby;
  late String _deviceId;
  late String _advert;
  late void Function(DiscoveredPeer) _onPeer;
  late void Function(String) _onPeerLost;
  late void Function(PeerChannel) _onIncoming;
  bool _running = false;

  final Map<String, _NearbyChannel> _channels = {};
  final Map<String, Completer<PeerChannel>> _pendingOutgoing = {};
  final Map<String, String> _deviceByEndpoint = {};

  @override
  String get name => 'nearby';

  @override
  Future<void> start({
    required String deviceId,
    required Set<String> tags,
    required void Function(DiscoveredPeer peer) onPeer,
    required void Function(String deviceId) onPeerLost,
    required void Function(PeerChannel channel) onIncoming,
  }) async {
    _deviceId = deviceId;
    _onPeer = onPeer;
    _onPeerLost = onPeerLost;
    _onIncoming = onIncoming;
    _advert = encodeAdvert(deviceId, tags, maxTags: 4);
    _running = true;
    await _startRadios();
  }

  Future<void> _startRadios() async {
    try {
      await _nearby.startAdvertising(
        _advert,
        Strategy.P2P_CLUSTER,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
        serviceId: serviceId,
      );
      await _nearby.startDiscovery(
        _advert,
        Strategy.P2P_CLUSTER,
        onEndpointFound: _onEndpointFound,
        onEndpointLost: (id) {
          final device = id == null ? null : _deviceByEndpoint.remove(id);
          if (device != null) _onPeerLost(device);
        },
        serviceId: serviceId,
      );
    } catch (e) {
      debugPrint('Nearby start failed: $e');
      rethrow;
    }
  }

  void _onEndpointFound(String endpointId, String endpointName, String svc) {
    final decoded = decodeAdvert(endpointName);
    if (decoded == null || decoded.$1 == _deviceId) return;
    _deviceByEndpoint[endpointId] = decoded.$1;
    _onPeer(DiscoveredPeer(
      deviceId: decoded.$1,
      tags: decoded.$2,
      transport: name,
      connect: () => _connect(endpointId),
    ));
  }

  /// Opens a new connection. Each connection is handed out exactly once
  /// (here or through `onIncoming`); the sync manager shares it between
  /// families, so an already-open one means it is in use elsewhere.
  Future<PeerChannel> _connect(String endpointId) async {
    final existing = _channels[endpointId];
    if (existing != null && !existing.closed) {
      throw StateError('Already connected to this phone');
    }
    final completer = Completer<PeerChannel>();
    _pendingOutgoing[endpointId] = completer;
    try {
      final ok = await _nearby.requestConnection(
        _advert,
        endpointId,
        onConnectionInitiated: _onConnectionInitiated,
        onConnectionResult: _onConnectionResult,
        onDisconnected: _onDisconnected,
      );
      if (!ok) throw StateError('Nearby connection request failed');
    } catch (e) {
      _pendingOutgoing.remove(endpointId);
      rethrow;
    }
    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pendingOutgoing.remove(endpointId);
        throw TimeoutException('Nearby connection timed out');
      },
    );
  }

  void _onConnectionInitiated(String endpointId, ConnectionInfo info) {
    // Learn who this is even if discovery missed them (the endpoint name is
    // their advert).
    final decoded = decodeAdvert(info.endpointName);
    if (decoded != null) _deviceByEndpoint[endpointId] = decoded.$1;
    _channels[endpointId]?.markClosed();
    _channels[endpointId] = _NearbyChannel(endpointId, _nearby);
    unawaited(_nearby.acceptConnection(
      endpointId,
      onPayLoadRecieved: _onPayload,
    ));
  }

  void _onConnectionResult(String endpointId, Status status) {
    final channel = _channels[endpointId];
    final pending = _pendingOutgoing.remove(endpointId);
    if (status != Status.CONNECTED || channel == null) {
      pending?.completeError(StateError('Nearby connection $status'));
      _channels.remove(endpointId)?.markClosed();
      return;
    }
    if (pending != null) {
      pending.complete(channel);
    } else {
      _onIncoming(channel);
    }
  }

  void _onDisconnected(String endpointId) {
    _channels.remove(endpointId)?.markClosed();
  }

  void _onPayload(String endpointId, Payload payload) {
    final bytes = payload.bytes;
    if (payload.type != PayloadType.BYTES || bytes == null) return;
    _channels[endpointId]?.deliver(bytes);
  }

  @override
  Future<void> updateTags(Set<String> tags) async {
    if (!_running) return;
    _advert = encodeAdvert(_deviceId, tags, maxTags: 4);
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _startRadios();
  }

  @override
  Future<void> stop() async {
    _running = false;
    await _nearby.stopAdvertising();
    await _nearby.stopDiscovery();
    await _nearby.stopAllEndpoints();
    for (final c in _channels.values) {
      c.markClosed();
    }
    _channels.clear();
    _deviceByEndpoint.clear();
  }
}

class _NearbyChannel implements PeerChannel {
  _NearbyChannel(this.endpointId, this._nearby);

  final String endpointId;
  final Nearby _nearby;
  final _incoming = StreamController<Uint8List>();
  bool closed = false;

  @override
  Stream<Uint8List> get incoming => _incoming.stream;

  @override
  String get transport => 'nearby';

  @override
  int get maxMessageBytes => NearbyTransport.maxPayload;

  void deliver(Uint8List bytes) {
    if (!_incoming.isClosed) _incoming.add(bytes);
  }

  void markClosed() {
    closed = true;
    if (!_incoming.isClosed) unawaited(_incoming.close());
  }

  @override
  Future<void> send(Uint8List message) =>
      _nearby.sendBytesPayload(endpointId, message);

  @override
  Future<void> close() async {
    if (closed) return;
    markClosed();
    await _nearby.disconnectFromEndpoint(endpointId);
  }
}
