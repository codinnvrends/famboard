import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/ids.dart';
import '../data/db/connection.dart';
import '../data/db/database.dart';
import '../data/famboard_repository.dart';
import '../data/key_vault.dart';
import '../data/record_store.dart';
import '../data/settings_store.dart';
import '../services/backup.dart';
import '../services/categorizer/categorizer.dart';
import '../services/receipt/bill_scanner.dart';
import '../services/receipt/receipt_parser.dart';
import '../services/notifications.dart';
import '../services/share_intake.dart';
import '../services/text_extractor.dart';
import '../services/voice.dart';
import '../sync/lan_transport.dart';
import '../sync/nearby_transport.dart';
import '../sync/sync_health.dart';
import '../sync/sync_manager.dart';
import '../sync/transport.dart';

/// Everything the app needs, created once at startup.
class AppServices {
  AppServices({
    required this.db,
    required this.store,
    required this.settings,
    required this.vault,
    required this.repo,
    required this.sync,
    required this.notifications,
    required this.voice,
    required this.share,
    required this.backup,
    required this.families,
    required this.deviceId,
    required this.health,
  });

  final AppDatabase db;
  final RecordStore store;
  final SettingsStore settings;
  final KeyVault vault;
  final FamBoardRepository repo;
  final SyncManager sync;
  final NotificationService notifications;
  final VoiceInput voice;
  final ShareIntake share;
  final BackupService backup;
  final FamiliesNotifier families;
  final String deviceId;
  final SyncHealthMonitor health;
  final Categorizer categorizer = Categorizer();
  final TextExtractor extractor = TextExtractor();
  final SmsBillParser smsParser = SmsBillParser();
  late final BillScanner billScanner = BillScanner(parser: ReceiptParser(categorizer: categorizer));

  static Future<AppServices> create() async {
    final vault = SecureKeyVault();
    final dir = await getApplicationSupportDirectory();
    final db = openEncryptedDatabase(
      File(p.join(dir.path, 'famboard.db')),
      await vault.databaseKey(),
    );
    return assemble(
      db: db,
      vault: vault,
      transports: [
        LanTransport(),
        if (!kIsWeb && Platform.isAndroid) NearbyTransport(),
      ],
      notifications: NotificationService(),
      healthChecker: AndroidSyncHealthChecker(),
    );
  }

  /// Wires the services together; tests pass in-memory pieces.
  static Future<AppServices> assemble({
    required AppDatabase db,
    required KeyVault vault,
    required List<SyncTransport> transports,
    required NotificationService notifications,
    SyncHealthChecker? healthChecker,
    String? defaultDeviceName,
  }) async {
    final settings = SettingsStore(db);
    var deviceId = await settings.get(SettingsStore.kDeviceId);
    if (deviceId == null) {
      deviceId = randomHex(8);
      await settings.set(SettingsStore.kDeviceId, deviceId);
    }
    if (await settings.get(SettingsStore.kDeviceName) == null) {
      await settings.set(SettingsStore.kDeviceName, defaultDeviceName ?? _guessDeviceName());
    }
    final store = await RecordStore.open(db, deviceId);
    final repo = FamBoardRepository(store: store, settings: settings, vault: vault);
    final nearbyEnabled = await settings.get(SettingsStore.kNearby) != 'false';
    final sync = SyncManager(
      store: store,
      repo: repo,
      settings: settings,
      vault: vault,
      transports: [
        for (final t in transports)
          if (t.name != 'nearby' || nearbyEnabled) t,
      ],
    );
    final families = FamiliesNotifier(settings);
    await families.load();
    await notifications.init();
    final share = ShareIntake();
    await share.init();
    return AppServices(
      db: db,
      store: store,
      settings: settings,
      vault: vault,
      repo: repo,
      sync: sync,
      notifications: notifications,
      voice: VoiceInput(),
      share: share,
      backup: BackupService(store: store, repo: repo, settings: settings, vault: vault),
      families: families,
      deviceId: deviceId,
      health: SyncHealthMonitor(
        healthChecker ?? NoopSyncHealthChecker(),
        nearbyEnabled: () async =>
            await settings.get(SettingsStore.kNearby) != 'false' && transports.any((t) => t.name == 'nearby'),
      ),
    );
  }

  static String _guessDeviceName() {
    if (kIsWeb) return 'Browser';
    if (Platform.isAndroid) return 'Android phone';
    if (Platform.isIOS) return 'iPhone';
    return 'Phone';
  }
}

/// Families on this device, kept in memory for the router's redirect.
class FamiliesNotifier extends ChangeNotifier {
  FamiliesNotifier(this._settings);

  final SettingsStore _settings;
  List<LocalFamily> _families = const [];
  StreamSubscription<List<LocalFamily>>? _sub;

  List<LocalFamily> get value => _families;
  bool get isEmpty => _families.isEmpty;

  /// Re-reads the families now (used right after creating or joining, so
  /// navigation doesn't race the database stream).
  Future<void> refresh() async {
    _families = await _settings.families();
    notifyListeners();
  }

  Future<void> load() async {
    _families = await _settings.families();
    _sub = _settings.watchFamilies().listen((f) {
      _families = f;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
