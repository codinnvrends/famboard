import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/settings_store.dart';
import '../domain/models.dart';
import '../l10n/app_localizations.dart';
import '../services/notifications.dart';
import '../sync/sync_session.dart';
import 'providers.dart';
import 'router.dart';
import 'services.dart';
import 'theme.dart';

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class FamBoardApp extends ConsumerStatefulWidget {
  const FamBoardApp({super.key});

  @override
  ConsumerState<FamBoardApp> createState() => _FamBoardAppState();
}

class _FamBoardAppState extends ConsumerState<FamBoardApp> with WidgetsBindingObserver {
  late final GoRouter _router;
  late final AppServices _services;
  StreamSubscription<SyncResult>? _resultsSub;
  Timer? _reminderDebounce;

  @override
  void initState() {
    super.initState();
    final services = _services = ref.read(servicesProvider);
    _router = buildRouter(services.families);
    WidgetsBinding.instance.addObserver(this);
    services.families.addListener(_onFamiliesChanged);
    _resultsSub = services.sync.results.listen(_onSyncResult);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFamiliesChanged());
  }

  @override
  void dispose() {
    _services.families.removeListener(_onFamiliesChanged);
    WidgetsBinding.instance.removeObserver(this);
    _resultsSub?.cancel();
    _reminderDebounce?.cancel();
    super.dispose();
  }

  /// True while the first-run permission dialogs are on screen. Each dialog
  /// briefly sends the app through "resumed"; starting sync then would try
  /// Bluetooth before it is allowed.
  bool _askingPermissions = false;

  /// Sync only runs while the app is open (iOS stops it in the background
  /// anyway); it starts once this phone belongs to a family.
  Future<void> _onFamiliesChanged() async {
    final services = ref.read(servicesProvider);
    if (services.families.isEmpty) return;
    await _firstRunPermissions();
    await _startSync();
  }

  Future<void> _startSync() async {
    final services = ref.read(servicesProvider);
    if (_askingPermissions || services.families.isEmpty) return;
    await services.health.refresh();
    await services.sync.start();
    await services.sync.retryTransports();
  }

  Future<void> _firstRunPermissions() async {
    final services = ref.read(servicesProvider);
    final settings = services.settings;
    if (await settings.get('permissionsAsked') == 'true') return;
    _askingPermissions = true;
    try {
      await settings.set('permissionsAsked', 'true');
      if (!kIsWeb && Platform.isAndroid && await settings.get(SettingsStore.kNearby) != 'false') {
        await services.health.checker.requestPermissions();
      }
      await services.notifications.requestPermission();
    } finally {
      _askingPermissions = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final services = ref.read(servicesProvider);
    if (state == AppLifecycleState.resumed && !services.families.isEmpty) {
      // Coming back from Settings may have fixed permissions or Location.
      unawaited(_startSync().then((_) => services.sync.syncAll(force: true)));
    } else if (state == AppLifecycleState.paused && !_askingPermissions) {
      unawaited(services.sync.stop());
    }
  }

  void _onSyncResult(SyncResult r) {
    if (r.received == 0) return;
    final context = scaffoldMessengerKey.currentContext;
    if (context == null) return;
    final l = AppLocalizations.of(context);
    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.syncReceived(r.received, r.peerName))));
  }

  void _scheduleReminders(List<Entry> entries) {
    _reminderDebounce?.cancel();
    _reminderDebounce = Timer(const Duration(seconds: 3), () async {
      final context = scaffoldMessengerKey.currentContext;
      if (context == null) return;
      final l = AppLocalizations.of(context);
      final services = ref.read(servicesProvider);
      final s = services.settings;
      final digest = (await s.get(SettingsStore.kDigestTime) ?? '08:00').split(':');
      await services.notifications.reschedule(
        entries: entries,
        enabled: await s.get(SettingsStore.kNotifications) != 'false',
        billLeadDays: int.tryParse(await s.get(SettingsStore.kBillLeadDays) ?? '') ?? 3,
        digestTime: TimeOfDay(hour: int.parse(digest[0]), minute: int.parse(digest[1])),
        texts: ReminderTexts(
          channelName: l.notifChannel,
          dueToday: l.notifDueToday,
          dueIn: l.notifDueIn,
          digestTitle: l.notifDigestTitle,
          digestBody: l.notifDigestBody,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeCode = ref.watch(settingProvider(SettingsStore.kLocale)).value;
    final large = ref.watch(settingProvider(SettingsStore.kLargeText)).value == 'true';
    // Reschedule reminders whenever the board changes.
    final session = ref.watch(sessionProvider);
    if (session != null) {
      ref.listen(entriesProvider(session.familyId), (_, next) {
        final list = next.value;
        if (list != null) _scheduleReminders(list);
      });
    }

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: FamTheme.light(large: large),
      darkTheme: FamTheme.dark(large: large),
      locale: localeCode == null ? null : Locale(localeCode),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: large
              ? media.copyWith(
                  textScaler: TextScaler.linear((media.textScaler.scale(1) * 1.25).clamp(1.0, 2.0)),
                )
              : media,
          child: child!,
        );
      },
    );
  }
}
