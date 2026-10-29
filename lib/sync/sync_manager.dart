import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/famboard_repository.dart';
import '../data/key_vault.dart';
import '../data/record_store.dart';
import '../data/settings_store.dart';
import 'channel.dart';
import 'secure_channel.dart';
import 'sync_session.dart';
import 'transport.dart';

/// A family device currently reachable.
class LivePeer {
  const LivePeer({
    required this.deviceId,
    required this.transport,
    required this.tags,
    this.name,
  });

  final String deviceId;
  final String transport;
  final Set<String> tags;
  final String? name;
}

/// Last successful sync for a family, shown in the sync badge.
class LastSync {
  const LastSync({required this.at, required this.peerName, required this.transport});

  final DateTime at;
  final String peerName;
  final String transport;

  String encode() => jsonEncode({
        'at': at.millisecondsSinceEpoch,
        'peer': peerName,
        'via': transport,
      });

  static LastSync? decode(String? raw) {
    if (raw == null) return null;
    try {
      final m = jsonDecode(raw) as Map<String, Object?>;
      return LastSync(
        at: DateTime.fromMillisecondsSinceEpoch((m['at']! as num).toInt()),
        peerName: m['peer'] as String? ?? '',
        transport: m['via'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class SyncStatus {
  const SyncStatus({
    this.running = false,
    this.syncing = false,
    this.transports = const {},
    this.peers = const [],
    this.lastError,
  });

  final bool running;
  final bool syncing;

  /// Transports that started successfully.
  final Set<String> transports;
  final List<LivePeer> peers;
  final String? lastError;

  SyncStatus copyWith({
    bool? running,
    bool? syncing,
    Set<String>? transports,
    List<LivePeer>? peers,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        running: running ?? this.running,
        syncing: syncing ?? this.syncing,
        transports: transports ?? this.transports,
        peers: peers ?? this.peers,
        lastError: clearError ? null : lastError ?? this.lastError,
      );
}

/// Runs peer-to-peer sync while the app is open (spec FR-50–53):
/// discovers family devices on every available transport, syncs on
/// discovery, after local edits (debounced), every minute, and on demand.
class SyncManager {
  SyncManager({
    required this.store,
    required this.repo,
    required this.settings,
    required this.vault,
    required this.transports,
  });

  final RecordStore store;
  final FamBoardRepository repo;
  final SettingsStore settings;
  final KeyVault vault;
  final List<SyncTransport> transports;

  static const _cooldown = Duration(seconds: 20);
  static const _period = Duration(minutes: 1);

  final _status = StreamController<SyncStatus>.broadcast();
  SyncStatus _current = const SyncStatus();
  final Map<String, (String, Uint8List)> _families = {}; // tag → (id, key)
  final Map<String, LivePeer> _livePeers = {};
  final Map<String, DiscoveredPeer> _routes = {};
  final Map<String, DateTime> _lastAttempt = {};
  final Set<String> _busy = {};
  final _results = StreamController<SyncResult>.broadcast();
  StreamSubscription<String>? _localSub;
  StreamSubscription<List<LocalFamily>>? _familiesSub;
  Timer? _debounce;
  Timer? _periodic;
  late LocalIdentity _identity;

  Stream<SyncStatus> get status => _status.stream;
  SyncStatus get current => _current;

  /// Completed syncs, for UI feedback.
  Stream<SyncResult> get results => _results.stream;

  void _emit(SyncStatus s) {
    _current = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void>? _starting;
  Future<void>? _stopping;

  /// Starts discovery on every transport. Safe to call repeatedly.
  Future<void> start() async {
    await _stopping;
    if (_current.running) return;
    return _starting ??= _start().whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final deviceId = await settings.get(SettingsStore.kDeviceId) ?? 'unknown';
    final deviceName = await settings.get(SettingsStore.kDeviceName) ?? 'Phone';
    _identity = LocalIdentity(deviceId: deviceId, deviceName: deviceName);
    await _loadFamilies();
    final started = <String>{};
    String? error;
    for (final t in transports) {
      try {
        await t.start(
          deviceId: deviceId,
          tags: _families.keys.toSet(),
          onPeer: _onPeer,
          onPeerLost: _onPeerLost,
          onIncoming: _onIncoming,
        );
        started.add(t.name);
      } catch (e) {
        debugPrint('Transport ${t.name} failed to start: $e');
        error = '${t.name}: $e';
      }
    }
    _emit(_current.copyWith(running: true, transports: started, lastError: error));
    _localSub = store.localChanges.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), () => syncAll(force: true));
    });
    _familiesSub = settings.watchFamilies().skip(1).listen((_) async {
      await _loadFamilies();
      for (final t in transports) {
        if (_current.transports.contains(t.name)) {
          await t.updateTags(_families.keys.toSet());
        }
      }
    });
    _periodic = Timer.periodic(_period, (_) => syncAll());
  }

  Future<void> stop() async {
    await _starting;
    if (!_current.running) return;
    return _stopping ??= _stop().whenComplete(() => _stopping = null);
  }

  Future<void> _stop() async {
    _debounce?.cancel();
    _periodic?.cancel();
    await _localSub?.cancel();
    await _familiesSub?.cancel();
    for (final t in transports) {
      try {
        await t.stop();
      } catch (e) {
        debugPrint('Transport ${t.name} failed to stop: $e');
      }
    }
    _livePeers.clear();
    _routes.clear();
    _emit(const SyncStatus());
  }

  Future<void> _loadFamilies() async {
    _families.clear();
    final keys = await vault.allFamilyKeys();
    final local = await settings.families();
    for (final f in local) {
      final key = keys[f.id];
      if (key == null) continue;
      _families[await familyTag(key)] = (f.id, key);
    }
  }

  void _onPeer(DiscoveredPeer peer) {
    final shared = peer.tags.intersection(_families.keys.toSet());
    if (shared.isEmpty) return;
    // Prefer Wi‑Fi over Nearby when both can reach the same device.
    final existing = _routes[peer.deviceId];
    if (existing == null || existing.transport != 'wifi' || peer.transport == 'wifi') {
      _routes[peer.deviceId] = peer;
    }
    _livePeers[peer.deviceId] = LivePeer(
      deviceId: peer.deviceId,
      transport: _routes[peer.deviceId]!.transport,
      tags: peer.tags,
      name: peer.name,
    );
    _emit(_current.copyWith(peers: _livePeers.values.toList()));
    // The device with the lower id connects, so both don't dial at once.
    if (_identity.deviceId.compareTo(peer.deviceId) < 0) {
      unawaited(_syncWith(peer.deviceId));
    }
  }

  void _onPeerLost(String deviceId) {
    _livePeers.remove(deviceId);
    _routes.remove(deviceId);
    _emit(_current.copyWith(peers: _livePeers.values.toList()));
  }

  Future<void> _onIncoming(PeerChannel channel) async {
    _emit(_current.copyWith(syncing: true));
    try {
      final result = await _session().accept(
        channel: channel,
        lookup: (tag) async => _families[tag],
      );
      await _recordResult(result);
    } catch (e) {
      debugPrint('Incoming sync failed: $e');
      _emit(_current.copyWith(lastError: e.toString()));
      await channel.close();
    } finally {
      _emit(_current.copyWith(syncing: _busy.isNotEmpty));
    }
  }

  /// Syncs with every reachable family device. [force] skips the cooldown.
  Future<void> syncAll({bool force = false}) async {
    await Future.wait(_routes.keys.map((d) => _syncWith(d, force: force)));
  }

  Future<void> _syncWith(String deviceId, {bool force = false}) async {
    if (_busy.contains(deviceId)) return;
    final last = _lastAttempt[deviceId];
    if (!force && last != null && DateTime.now().difference(last) < _cooldown) return;
    final route = _routes[deviceId];
    if (route == null) return;
    _busy.add(deviceId);
    _lastAttempt[deviceId] = DateTime.now();
    _emit(_current.copyWith(syncing: true));
    try {
      final shared = route.tags.intersection(_families.keys.toSet());
      for (final tag in shared) {
        final (familyId, key) = _families[tag]!;
        final channel = await route.connect();
        final result = await _session().initiate(
          channel: channel,
          familyId: familyId,
          familyKey: key,
        );
        await _recordResult(result);
      }
      _emit(_current.copyWith(clearError: true));
    } catch (e) {
      debugPrint('Sync with $deviceId failed: $e');
      _emit(_current.copyWith(lastError: e.toString()));
    } finally {
      _busy.remove(deviceId);
      _emit(_current.copyWith(syncing: _busy.isNotEmpty));
    }
  }

  SyncSession _session() => SyncSession(
        store: store,
        identity: _identity,
        memberIdFor: (familyId) async => (await settings.families())
            .where((f) => f.id == familyId)
            .map((f) => f.memberId)
            .firstOrNull,
        // Unknown members are allowed: a phone that just joined holds the
        // family key but its member record hasn't reached us yet.
        isMemberAllowed: (familyId, memberId) async {
          final members = await repo.members(familyId);
          final m = members.where((m) => m.id == memberId).firstOrNull;
          return m == null || !m.removed;
        },
      );

  Future<void> _recordResult(SyncResult r) async {
    final peerName = r.peerName.isEmpty ? 'Phone' : r.peerName;
    await settings.recordPeer(
      deviceId: r.peerDeviceId,
      familyId: r.familyId,
      name: peerName,
      transport: r.transport,
      synced: true,
    );
    await settings.set(
      SettingsStore.lastSyncKey(r.familyId),
      LastSync(at: DateTime.now(), peerName: peerName, transport: r.transport).encode(),
    );
    final live = _livePeers[r.peerDeviceId];
    if (live != null) {
      _livePeers[r.peerDeviceId] = LivePeer(
        deviceId: live.deviceId,
        transport: live.transport,
        tags: live.tags,
        name: peerName,
      );
      _emit(_current.copyWith(peers: _livePeers.values.toList()));
    }
    if (!_results.isClosed) _results.add(r);
  }

  Future<void> dispose() async {
    await stop();
    await _status.close();
    await _results.close();
  }
}
