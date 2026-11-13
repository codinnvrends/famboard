import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../services/receipt/bill_scanner.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

const _kHindiBills = 'scan.hindi';

/// Asks camera or gallery, reads the photos on the phone, then opens the
/// review screen.
Future<void> startBillScan(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final services = ref.read(servicesProvider);
  final scanner = services.billScanner;
  final hindiSaved = await services.settings.get(_kHindiBills) == 'true';
  if (!context.mounted) return;

  final choice = await showModalBottomSheet<(bool camera, bool hindi)>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      var hindi = hindiSaved;
      return StatefulBuilder(
        builder: (sheet, setState) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
                child: Text(l.scanBill, style: Theme.of(sheet).textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(l.scanBillBody, style: Theme.of(sheet).textTheme.bodyMedium),
              ),
              if (scanner.canUseCameraScanner)
                ListTile(
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: Text(l.scanBillCamera),
                  subtitle: Text(l.scanBillCameraBody),
                  onTap: () => Navigator.pop(sheet, (true, hindi)),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l.scanBillGallery),
                subtitle: Text(l.scanBillGalleryBody),
                onTap: () => Navigator.pop(sheet, (false, hindi)),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.translate),
                title: Text(l.scanBillHindi),
                value: hindi,
                onChanged: (v) => setState(() => hindi = v),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
  if (choice == null || !context.mounted) return;
  final (camera, hindi) = choice;
  if (hindi != hindiSaved) await services.settings.set(_kHindiBills, '$hindi');

  List<String> paths;
  try {
    paths = camera ? await scanner.scanWithCamera() : await scanner.pickPhotos();
  } on ScannerUnavailable {
    if (context.mounted) showSnack(context, l.scanCameraUnavailable);
    paths = await scanner.pickPhotos();
  }
  if (paths.isEmpty || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(l.scanReading(paths.length))),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    final bill = await scanner.read(paths, hindi: hindi);
    navigator.pop();
    if (!context.mounted) return;
    if (bill.items.isEmpty) {
      showSnack(context, l.scanNothingFound);
      return;
    }
    await context.push('/bill-review', extra: bill);
  } catch (_) {
    navigator.pop();
    if (context.mounted) showSnack(context, l.scanFailed);
  }
}
