import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

import 'channel.dart';
import 'transport.dart';

/// Same-Wi‑Fi sync: advertises `_famboard._tcp` over mDNS and talks over a
/// TCP socket. Works between Android and iOS, and needs a router but not the
/// internet.
class LanTransport implements SyncTransport {
  static const serviceType = '_famboard._tcp';

  ServerSocket? _server;
  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;
  late String _deviceId;
  late void Function(DiscoveredPeer) _onPeer;
  late void Function(String) _onPeerLost;
  final Map<String, String> _deviceByServiceName = {};

  @override
  String get name => 'wifi';

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
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
    _server!.listen(
      (socket) => onIncoming(SocketChannel(socket)),
      onError: (Object e) => debugPrint('LAN server error: $e'),
    );
    await _advertise(tags);
    await _discover();
  }

  Future<void> _advertise(Set<String> tags) async {
    await _broadcast?.stop();
    final service = BonsoirService(
      name: 'FamBoard ${_deviceId.substring(0, 6)}',
      type: serviceType,
      port: _server!.port,
      attributes: {'d': _deviceId, 't': tags.take(15).join(',')},
    );
    final broadcast = BonsoirBroadcast(service: service);
    await broadcast.initialize();
    await broadcast.start();
    _broadcast = broadcast;
  }

  Future<void> _discover() async {
    final discovery = BonsoirDiscovery(type: serviceType);
    await discovery.initialize();
    _discoverySub = discovery.eventStream?.listen((event) async {
      final service = event.service;
      if (service == null) return;
      switch (event) {
        case BonsoirDiscoveryServiceFoundEvent():
          if (service.attributes['d'] != _deviceId) {
            await service.resolve(discovery.serviceResolver);
          }
        case BonsoirDiscoveryServiceResolvedEvent():
        case BonsoirDiscoveryServiceUpdatedEvent():
          _handleResolved(service);
        case BonsoirDiscoveryServiceLostEvent():
          final device = _deviceByServiceName.remove(service.name);
          if (device != null) _onPeerLost(device);
        default:
          break;
      }
    });
    await discovery.start();
    _discovery = discovery;
  }

  void _handleResolved(BonsoirService service) {
    final device = service.attributes['d'];
    if (device == null || device == _deviceId) return;
    final address = service.hostAddresses
            .where((a) => InternetAddress.tryParse(a)?.type == InternetAddressType.IPv4)
            .firstOrNull ??
        service.hostAddresses.firstOrNull ??
        service.hostname;
    if (address == null) return;
    _deviceByServiceName[service.name] = device;
    final tags = (service.attributes['t'] ?? '').split(',').where((t) => t.isNotEmpty).toSet();
    final port = service.port;
    _onPeer(DiscoveredPeer(
      deviceId: device,
      tags: tags,
      transport: name,
      connect: () async {
        final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 8));
        return SocketChannel(socket);
      },
    ));
  }

  @override
  Future<void> updateTags(Set<String> tags) async {
    if (_server == null) return;
    await _advertise(tags);
    // Re-discover so other phones' adverts are read fresh (Android caches
    // them, and a family they just joined wouldn't show).
    await _discoverySub?.cancel();
    await _discovery?.stop();
    _deviceByServiceName.clear();
    await _discover();
  }

  @override
  Future<void> stop() async {
    await _discoverySub?.cancel();
    await _discovery?.stop();
    await _broadcast?.stop();
    await _server?.close();
    _discovery = null;
    _broadcast = null;
    _server = null;
    _deviceByServiceName.clear();
  }
}

/// A [PeerChannel] over a TCP socket with length-prefixed framing.
class SocketChannel implements PeerChannel {
  SocketChannel(this._socket)
      // Single-subscription on purpose: bytes that arrive before the session
      // starts reading are buffered, not dropped.
      : incoming = _socket.transform(const LengthPrefixedFramer());

  final Socket _socket;

  @override
  final Stream<Uint8List> incoming;

  @override
  String get transport => 'wifi';

  @override
  int get maxMessageBytes => 1024 * 1024;

  @override
  Future<void> send(Uint8List message) async {
    _socket.add(LengthPrefixedFramer.frame(message));
    await _socket.flush();
  }

  @override
  Future<void> close() async {
    try {
      await _socket.close();
    } catch (_) {
      _socket.destroy();
    }
  }
}
