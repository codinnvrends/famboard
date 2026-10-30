import 'channel.dart';

/// A family device seen on some transport.
class DiscoveredPeer {
  DiscoveredPeer({
    required this.deviceId,
    required this.tags,
    required this.transport,
    required this.connect,
    this.name,
  });

  final String deviceId;

  /// Family tags the peer advertises (see `familyTag`).
  final Set<String> tags;
  final String transport;
  final String? name;

  /// Opens a channel to the peer.
  final Future<PeerChannel> Function() connect;
}

/// Something that can advertise this device and find peers.
abstract class SyncTransport {
  String get name;

  /// Starts advertising [tags] and discovering peers.
  Future<void> start({
    required String deviceId,
    required Set<String> tags,
    required void Function(DiscoveredPeer peer) onPeer,
    required void Function(String deviceId) onPeerLost,
    required void Function(PeerChannel channel) onIncoming,
  });

  /// Re-advertises after the set of families changes.
  Future<void> updateTags(Set<String> tags);

  Future<void> stop();
}

/// Encodes advertised data into a short string: `<deviceId>|<tag>,<tag>`.
String encodeAdvert(String deviceId, Set<String> tags, {int maxTags = 6}) =>
    '$deviceId|${tags.take(maxTags).join(',')}';

(String, Set<String>)? decodeAdvert(String raw) {
  final i = raw.indexOf('|');
  if (i <= 0) return null;
  final tags = raw.substring(i + 1).split(',').where((t) => t.isNotEmpty).toSet();
  return (raw.substring(0, i), tags);
}
