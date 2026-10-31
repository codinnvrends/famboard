import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../services/backup.dart';
import '../../services/share_intake.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../entries/sms_paste.dart';
import '../settings/backup_flow.dart';

/// Handles what other apps send to FamBoard: bill text becomes a quick-add,
/// a backup file starts a restore. Mix into any screen that can be on top
/// (home, or welcome on a fresh install).
mixin ShareHandler<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  StreamSubscription<Shared>? _shareSub;

  /// Whether this screen can turn text into a new entry (needs a family).
  bool get acceptsText => true;

  @override
  void initState() {
    super.initState();
    final intake = ref.read(servicesProvider).share;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = intake.pending;
      if (pending != null) _handle(pending);
    });
    _shareSub = intake.items.listen(_handle);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  Future<void> _handle(Shared item) async {
    if (!mounted) return;
    if (item is SharedText && !acceptsText) return;
    final intake = ref.read(servicesProvider).share;
    if (!intake.claim(item)) return;
    switch (item) {
      case SharedText(:final text):
        await openFromSharedText(context, text);
      case SharedFile():
        final bytes = await item.read();
        if (!mounted) return;
        if (BackupService.looksLikeBackup(bytes)) {
          await restoreBackupBytes(context, ref, bytes);
        } else {
          showSnack(context, context.l10n.backupNotABackup);
        }
    }
  }
}
