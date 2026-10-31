import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../services/backup.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

/// Asks for a passphrase. With [confirm], asks twice so a typo can't lock
/// the user out of their own backup.
Future<String?> askPassphrase(BuildContext context, {bool confirm = false}) async {
  final l = context.l10n;
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.backupPassphrase),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: first,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l.backupPassphrase,
                helperText: confirm ? l.backupPassphraseHint : null,
                helperMaxLines: 3,
              ),
            ),
            if (confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: second,
                obscureText: true,
                decoration: InputDecoration(labelText: l.backupPassphraseAgain, errorText: error),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
            onPressed: () {
              if (confirm && first.text.length < 6) {
                setState(() => error = l.backupPassphraseHint);
              } else if (confirm && first.text != second.text) {
                setState(() => error = l.backupPassphraseMismatch);
              } else {
                Navigator.pop(ctx, first.text);
              }
            },
            child: Text(l.continueAction),
          ),
        ],
      ),
    ),
  );
}

/// Creates an encrypted backup of the active family, then offers to save it
/// to a folder the user picks (so it survives uninstalling the app) or
/// share it (WhatsApp, email, Drive…).
Future<void> createBackupFlow(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final session = ref.read(sessionProvider);
  if (session == null) return;
  final pass = await askPassphrase(context, confirm: true);
  if (pass == null || !context.mounted) return;
  final Uint8List bytes;
  try {
    bytes = await ref.read(servicesProvider).backup.createBackup(session.familyId, pass);
  } on BackupException catch (e) {
    if (context.mounted) showSnack(context, e.message);
    return;
  }
  final name = BackupService.fileName(ref.read(familyNameProvider), DateTime.now());
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.backupReady, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(name, style: Theme.of(sheet).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(l.backupReadyBody, style: Theme.of(sheet).textTheme.bodyMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.save_alt),
              label: Text(l.backupSaveToPhone),
              onPressed: () async {
                final uri = await FilePicker.saveFile(
                  fileName: name,
                  bytes: bytes,
                  mimeType: BackupService.mimeType,
                  dialogTitle: l.backupSaveToPhone,
                );
                if (uri != null && context.mounted) {
                  showSnack(context, l.backupSaved);
                  if (sheet.mounted) Navigator.pop(sheet);
                }
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.share_outlined),
              label: Text(l.backupShare),
              onPressed: () async {
                final dir = await getTemporaryDirectory();
                final file = File(p.join(dir.path, name));
                await file.writeAsBytes(bytes, flush: true);
                await SharePlus.instance.share(ShareParams(
                  files: [XFile(file.path, mimeType: BackupService.mimeType, name: name)],
                  subject: name,
                  text: l.backupShareText,
                ));
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Picks a backup file and restores it.
Future<void> pickAndRestoreBackup(BuildContext context, WidgetRef ref) async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty || !context.mounted) return;
  final bytes = await files.first.xFile.readAsBytes();
  if (!context.mounted) return;
  await restoreBackupBytes(context, ref, bytes);
}

/// Restores [bytes] after asking for the passphrase (also used when a
/// backup is opened from WhatsApp or a file manager).
Future<void> restoreBackupBytes(BuildContext context, WidgetRef ref, List<int> bytes) async {
  final l = context.l10n;
  if (!BackupService.looksLikeBackup(bytes)) {
    showSnack(context, l.backupNotABackup);
    return;
  }
  final pass = await askPassphrase(context);
  if (pass == null || !context.mounted) return;
  final services = ref.read(servicesProvider);
  try {
    final family = await services.backup.restoreBackup(Uint8List.fromList(bytes), pass);
    await services.families.refresh();
    if (!context.mounted) return;
    showSnack(context, l.backupRestored(family.name));
    context.go('/today');
  } on BackupException catch (e) {
    if (context.mounted) {
      showSnack(
        context,
        e.message == 'Wrong passphrase.'
            ? l.backupWrongPassphrase
            : e.message == 'This is not a FamBoard backup.'
                ? l.backupNotABackup
                : e.message,
      );
    }
  }
}
