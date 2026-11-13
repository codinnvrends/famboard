import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart' as ph show openAppSettings;

/// Something on this phone that stops family phones finding each other.
enum SyncProblem {
  /// "Nearby devices" (Bluetooth scan/advertise/connect) not allowed.
  nearbyPermission,

  /// Location permission not allowed; Android needs it to scan Bluetooth.
  locationPermission,

  /// Location is switched off in quick settings; Bluetooth scans find
  /// nothing on most Android phones while it is off.
  locationOff,

  /// Bluetooth is switched off.
  bluetoothOff,

  /// Not connected to any Wi‑Fi (only matters if Bluetooth sync is also
  /// unavailable).
  noWifi,
}

/// Snapshot of what this phone can use for sync.
class SyncHealth {
  const SyncHealth({required this.problems, required this.onWifi});

  final Set<SyncProblem> problems;
  final bool onWifi;

  static const ok = SyncHealth(problems: {}, onWifi: true);

  bool get isOk => problems.isEmpty;

  /// Problems the user can fix by granting permissions in-app.
  bool get needsPermissions =>
      problems.contains(SyncProblem.nearbyPermission) ||
      problems.contains(SyncProblem.locationPermission);
}

/// Checks and requests what sync needs. Swappable for tests.
abstract class SyncHealthChecker {
  Future<SyncHealth> check({required bool nearbyEnabled});
  Future<void> requestPermissions();
  Future<void> openAppSettings();
}

class AndroidSyncHealthChecker implements SyncHealthChecker {
  static final _nearbyPermissions = [
    Permission.bluetoothScan,
    Permission.bluetoothAdvertise,
    Permission.bluetoothConnect,
  ];

  @override
  Future<SyncHealth> check({required bool nearbyEnabled}) async {
    final onWifi = await _hasLocalNetwork();
    if (kIsWeb || !Platform.isAndroid) {
      return SyncHealth(problems: {if (!onWifi) SyncProblem.noWifi}, onWifi: onWifi);
    }
    final problems = <SyncProblem>{};
    if (nearbyEnabled) {
      try {
        for (final p in _nearbyPermissions) {
          // On Android 11 and older these report granted automatically.
          if (!(await p.status).isGranted) {
            problems.add(SyncProblem.nearbyPermission);
            break;
          }
        }
        if (!(await Permission.locationWhenInUse.status).isGranted) {
          problems.add(SyncProblem.locationPermission);
        }
        if (await Permission.locationWhenInUse.serviceStatus != ServiceStatus.enabled) {
          problems.add(SyncProblem.locationOff);
        }
        if (await Permission.bluetooth.serviceStatus == ServiceStatus.disabled) {
          problems.add(SyncProblem.bluetoothOff);
        }
      } catch (e) {
        debugPrint('Sync health check failed: $e');
      }
    }
    if (!onWifi && (!nearbyEnabled || problems.isNotEmpty)) problems.add(SyncProblem.noWifi);
    return SyncHealth(problems: problems, onWifi: onWifi);
  }

  @override
  Future<void> requestPermissions() async {
    if (kIsWeb || !Platform.isAndroid) return;
    // One at a time: Android shows each group's dialog separately.
    await _nearbyPermissions.request();
    await Permission.nearbyWifiDevices.request();
    await Permission.locationWhenInUse.request();
  }

  @override
  Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }

  static Future<bool> _hasLocalNetwork() async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      return interfaces.any((i) {
        final name = i.name.toLowerCase();
        return (name.startsWith('wlan') || name.startsWith('en') || name.startsWith('eth') ||
                name.startsWith('ap') || name.startsWith('swlan')) &&
            i.addresses.any((a) => !a.isLoopback && !a.isLinkLocal);
      });
    } catch (_) {
      return true;
    }
  }
}

/// Always-healthy checker for tests and platforms without these checks.
class NoopSyncHealthChecker implements SyncHealthChecker {
  @override
  Future<SyncHealth> check({required bool nearbyEnabled}) async => SyncHealth.ok;

  @override
  Future<void> requestPermissions() async {}

  @override
  Future<void> openAppSettings() async {}
}

/// Keeps the latest [SyncHealth] and lets screens refresh it.
class SyncHealthMonitor {
  SyncHealthMonitor(this.checker, {required this.nearbyEnabled});

  final SyncHealthChecker checker;
  final Future<bool> Function() nearbyEnabled;
  SyncHealth _value = SyncHealth.ok;
  final _changes = StreamController<SyncHealth>.broadcast();

  SyncHealth get value => _value;
  Stream<SyncHealth> get changes => _changes.stream;

  Future<SyncHealth> refresh() async {
    _value = await checker.check(nearbyEnabled: await nearbyEnabled());
    if (!_changes.isClosed) _changes.add(_value);
    return _value;
  }
}
