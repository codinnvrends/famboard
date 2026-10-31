import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/famboard_repository.dart';
import '../data/key_vault.dart';
import '../data/record_store.dart';
import '../data/settings_store.dart';
import 'channel.dart';
import 'mux.dart';
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
    this.transportErrors = const {},
    this.peers = const [],
    this.lastError,
    this.log = const [],
  });

  final bool running;
  final bool syncing;

  /// Transports that started successfully.
  final Set<String> transports;

  /// Transports that failed to start, with the reason. Retried on resume,
  /// every minute, and when permissions change.
  final Map<String, String> transportErrors;
  final List<LivePeer> peers;
  final String? lastError;

  /// Recent sync events, newest first, for the diagnostics view.
  final List<SyncLogLine> log;

  SyncStatus copyWith({
    bool? running,
    bool? syncing,
    Set<String>? transports,
    Map<String, String>? transportErrors,
    List<LivePeer>? peers,
    String? lastError,
    bool clearError = false,
    List<SyncLogLine>? log,
  }) =>
      SyncStatus(
        running: running ?? this.running,
        syncing: syncing ?? this.syncing,
        transports: transports ?? this.transports,
        transportErrors: transportErrors ?? this.transportErrors,
        peers: peers ?? this.peers,
        lastError: clearError ? null : lastError ?? this.lastError,
        log: log ?? this.log,
      );
}

class SyncLogLine {
  const SyncLogLine(this.at, this.message);
  final DateTime at;
  final String message;
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

  /// Last successful sync per `device|family`.
  final Map<String, DateTime> _lastSuccess = {};

  /// `device|family` pairs the peer said it isn't in, and when.
  final Map<String, DateTime> _notMember = {};

  /// One shared connection per peer device, carrying a session per family.
  final Map<String, MuxConnection> _connections = {};

  /// Devices this phone has synced with before (in any family).
  final Set<String> _knownDevices = {};
  String _familyIdsKey = '';
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
    _knownDevices.addAll(await settings.knownDeviceIds());
    _emit(_current.copyWith(running: true, transports: {}, transportErrors: {}));
    _log('Sync started on ${_shortId(deviceId)} for ${_families.length} family(ies)');
    await retryTransports();
    _localSub = store.localChanges.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 2), () => syncAll(force: true));
    });
    _familiesSub = settings.watchFamilies().listen((families) async {
      // Settings change for many reasons (e.g. "last synced"); only a new or
      // removed family should re-advertise, since that restarts the radios.
      final key = (families.map((f) => f.id).toList()..sort()).join(',');
      if (key == _familyIdsKey) return;
      await _loadFamilies();
      _notMember.clear();
      _log('Families changed; now ${_families.length}');
      for (final t in transports) {
        if (_current.transports.contains(t.name)) {
          try {
            await t.updateTags(_families.keys.toSet());
          } catch (e) {
            _transportFailed(t, e);
          }
        }
      }
    });
    _periodic = Timer.periodic(_period, (_) async {
      await retryTransports();
      await syncAll();
    });
  }

  /// Starts any transport that isn't running (e.g. Bluetooth before its
  /// permission was granted). Safe to call any time.
  Future<void> retryTransports() async {
    if (!_current.running) return;
    for (final t in transports) {
      if (_current.transports.contains(t.name)) continue;
      try {
        // Clear half-started state (e.g. advertising up, discovery failed).
        await t.stop().catchError((Object _) {});
        await t.start(
          deviceId: _identity.deviceId,
          tags: _families.keys.toSet(),
          onPeer: _onPeer,
          onPeerLost: _onPeerLost,
          onIncoming: _onIncoming,
        );
        final errors = Map.of(_current.transportErrors)..remove(t.name);
        _emit(_current.copyWith(
          transports: {..._current.transports, t.name},
          transportErrors: errors,
        ));
        _log('${t.name} started');
      } catch (e) {
        _transportFailed(t, e);
      }
    }
  }

  void _transportFailed(SyncTransport t, Object e) {
    final reason = _describe(e);
    debugPrint('Transport ${t.name} failed: $reason');
    _emit(_current.copyWith(
      transports: {..._current.transports}..remove(t.name),
      transportErrors: {..._current.transportErrors, t.name: reason},
    ));
    _log('${t.name} could not start: $reason');
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
    for (final c in _connections.values.toList()) {
      await c.close();
    }
    _connections.clear();
    _livePeers.clear();
    _routes.clear();
    _emit(SyncStatus(log: _current.log));
  }

  Future<void> _loadFamilies() async {
    _families.clear();
    _familyIdsKey = ((await settings.families()).map((f) => f.id).toList()..sort()).join(',');
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
    // Adverts are cached by Android and can be out of date, so a phone we've
    // synced with before is worth trying even if its advert doesn't match.
    if (shared.isEmpty && !_knownDevices.contains(peer.deviceId)) return;
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
    _log('Found ${_shortId(peer.deviceId)} via ${peer.transport}');
    // The device with the lower id dials first so both don't dial at once;
    // the other follows up if some family still hasn't synced.
    if (_identity.deviceId.compareTo(peer.deviceId) < 0) {
      unawaited(_syncWith(peer.deviceId));
    } else {
      Timer(const Duration(seconds: 8), () {
        if (_needsSync(peer.deviceId)) unawaited(_syncWith(peer.deviceId, force: true));
      });
    }
  }

  bool _needsSync(String deviceId) {
    final now = DateTime.now();
    for (final (familyId, _) in _families.values) {
      final key = '$deviceId|$familyId';
      final notMember = _notMember[key];
      if (notMember != null && now.difference(notMember) < _notMemberTtl) continue;
      final last = _lastSuccess[key];
      if (last == null || now.difference(last) > const Duration(seconds: 30)) return true;
    }
    return false;
  }

  static const _notMemberTtl = Duration(minutes: 2);

  void _onPeerLost(String deviceId) {
    _log('Lost ${_shortId(deviceId)}');
    _livePeers.remove(deviceId);
    _routes.remove(deviceId);
    _emit(_current.copyWith(peers: _livePeers.values.toList()));
  }

  /// A phone connected to us: share the connection for every family.
  Future<void> _onIncoming(PeerChannel channel) async {
    final mux = _newMux(channel);
    try {
      final peer = await mux.peerId.timeout(const Duration(seconds: 15));
      _register(peer, mux);
    } catch (e) {
      _log('Incoming connection failed: ${_describe(e)}');
      await mux.close();
    }
  }

  MuxConnection _newMux(PeerChannel base) => MuxConnection(
        base,
        localId: _identity.deviceId,
        onStream: (stream) => unawaited(_acceptSession(stream)),
        onError: (e) {
          _log('Connection error: ${_describe(e)}');
          if (e is IncompatiblePeerException) _emit(_current.copyWith(lastError: e.toString()));
        },
      );

  void _register(String peer, MuxConnection mux) {
    final old = _connections[peer];
    _connections[peer] = mux;
    if (old != null && old != mux && !old.isClosed) {
      // Keep the older one until idle; sessions on it can finish.
      unawaited(old.done);
    }
    unawaited(mux.done.then((_) {
      if (_connections[peer] == mux) _connections.remove(peer);
    }));
  }

  Future<void> _acceptSession(PeerChannel stream) async {
    _emit(_current.copyWith(syncing: true));
    try {
      final result = await _session().accept(
        channel: stream,
        lookup: (tag) async => _families[tag],
      );
      await _recordResult(result);
    } on NotInFamilyException {
      await stream.close();
    } catch (e) {
      debugPrint('Incoming sync failed: $e');
      _log('Incoming sync failed: ${_describe(e)}');
      _emit(_current.copyWith(lastError: _describe(e)));
      await stream.close();
    } finally {
      _emit(_current.copyWith(syncing: _busy.isNotEmpty));
    }
  }

  /// The shared connection to [deviceId], dialling if there is none.
  Future<MuxConnection> _connectionTo(String deviceId) async {
    final existing = _connections[deviceId];
    if (existing != null && !existing.isClosed) return existing;
    final route = _routes[deviceId];
    if (route == null) throw StateError('Phone not in range');
    MuxConnection mux;
    try {
      mux = _newMux(await route.connect());
    } catch (e) {
      // Both phones dialled at once: the other side's connection may be the
      // one that got through. Give it a moment to introduce itself.
      for (var i = 0; i < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        final c = _connections[deviceId];
        if (c != null && !c.isClosed) return c;
      }
      rethrow;
    }
    final peer = await mux.peerId.timeout(const Duration(seconds: 15));
    _register(peer, mux);
    return mux;
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
    if (route == null && _connections[deviceId] == null) return;
    _busy.add(deviceId);
    _lastAttempt[deviceId] = DateTime.now();
    _emit(_current.copyWith(syncing: true));
    var failures = 0;
    try {
      final mux = await _connectionTo(deviceId);
      // Families the peer advertises first, then the rest: adverts can be
      // stale, and asking costs one round trip.
      final advertised = route?.tags ?? const <String>{};
      final tags = _families.keys.toList()
        ..sort((a, b) => (advertised.contains(a) ? 0 : 1).compareTo(advertised.contains(b) ? 0 : 1));
      final now = DateTime.now();
      for (final tag in tags) {
        final (familyId, key) = _families[tag]!;
        final pairKey = '$deviceId|$familyId';
        final notMember = _notMember[pairKey];
        if (notMember != null && now.difference(notMember) < _notMemberTtl) continue;
        if (mux.isClosed) break;
        try {
          final result = await _session().initiate(
            channel: await mux.open(),
            familyId: familyId,
            familyKey: key,
          );
          _notMember.remove(pairKey);
          await _recordResult(result);
        } on NotInFamilyException {
          _notMember[pairKey] = DateTime.now();
        } catch (e) {
          failures++;
          debugPrint('Sync of $familyId with $deviceId failed: $e');
          _log('Sync with ${_shortId(deviceId)} failed: ${_describe(e)}');
          _emit(_current.copyWith(lastError: _describe(e)));
        }
      }
      if (failures == 0) _emit(_current.copyWith(clearError: true));
    } catch (e) {
      debugPrint('Sync with $deviceId failed: $e');
      _log('Sync with ${_shortId(deviceId)} failed: ${_describe(e)}');
      _emit(_current.copyWith(lastError: _describe(e)));
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
    _lastSuccess['${r.peerDeviceId}|${r.familyId}'] = DateTime.now();
    _knownDevices.add(r.peerDeviceId);
    final family = (await settings.families()).where((f) => f.id == r.familyId).firstOrNull;
    _log('Synced ${family?.name ?? 'family'} with $peerName via ${r.transport}: '
        'sent ${r.sent}, got ${r.received}');
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

  void _log(String message) {
    final log = [SyncLogLine(DateTime.now(), message), ..._current.log];
    _emit(_current.copyWith(log: log.length > 60 ? log.sublist(0, 60) : log));
  }

  static String _shortId(String id) => id.length > 6 ? id.substring(0, 6) : id;

  static String _describe(Object e) {
    final text = e.toString();
    // PlatformException(Failure, 8034: MISSING_PERMISSION_..., null, null)
    final m = RegExp(r'PlatformException\([^,]*,\s*([^,]+)').firstMatch(text);
    return (m?.group(1) ?? text).trim();
  }

  Future<void> dispose() async {
    await stop();
    await _status.close();
    await _results.close();
  }
}
