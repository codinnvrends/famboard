import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../services/receipt/bill_scanner.dart';
import '../../services/warranty/warranty_parser.dart';
import '../../services/warranty/warranty_scanner.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

enum _Source { camera, gallery, manual }

/// Asks how to add (scan, gallery, by hand), reads the photos on the phone,
/// then opens the form with whatever OCR found, for the person to check.
Future<void> startApplianceAdd(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final services = ref.read(servicesProvider);
  final scanner = services.warrantyScanner;

  final source = await showModalBottomSheet<_Source>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Text(l.warrantyAdd, style: Theme.of(sheet).textTheme.titleLarge),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(l.warrantyAddBody, style: Theme.of(sheet).textTheme.bodyMedium),
          ),
          if (scanner.bills.canUseCameraScanner)
            ListTile(
              leading: const Icon(Icons.document_scanner_outlined),
              title: Text(l.warrantyScanCamera),
              subtitle: Text(l.warrantyScanCameraBody),
              onTap: () => Navigator.pop(sheet, _Source.camera),
            ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l.warrantyScanGallery),
            subtitle: Text(l.warrantyScanGalleryBody),
            onTap: () => Navigator.pop(sheet, _Source.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.edit_note),
            title: Text(l.warrantyManual),
            onTap: () => Navigator.pop(sheet, _Source.manual),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;
  if (source == _Source.manual) {
    await context.push('/appliance-new');
    return;
  }

  final paths = await pickWarrantyPhotos(context, scanner.bills, camera: source == _Source.camera);
  if (paths.isEmpty || !context.mounted) return;

  final scan = await _withProgress(context, l.warrantyReading(paths.length), () => scanner.read(paths));
  if (!context.mounted) return;
  if (scan == null) {
    showSnack(context, l.scanFailed);
    return;
  }
  await context.push('/appliance-new', extra: scan);
}

/// Camera (document scanner, falling back to gallery) or gallery paths.
Future<List<String>> pickWarrantyPhotos(BuildContext context, BillScanner bills, {required bool camera}) async {
  try {
    return camera ? await bills.scanWithCamera() : await bills.pickPhotos();
  } on ScannerUnavailable {
    if (context.mounted) showSnack(context, context.l10n.scanCameraUnavailable);
    return bills.pickPhotos();
  }
}

/// Runs [work] behind a blocking "Reading…" dialog. Null if it threw.
Future<T?> _withProgress<T>(BuildContext context, String message, Future<T> Function() work) async {
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
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } catch (e) {
    debugPrint('Warranty scan failed: $e');
    return null;
  } finally {
    navigator.pop();
  }
}

/// Compresses extra photos added on the form (no OCR).
Future<WarrantyScan?> readMorePhotos(BuildContext context, WarrantyScanner scanner, List<String> paths) =>
    _withProgress(context, context.l10n.warrantyReading(paths.length), () async {
      final photos = [
        for (final p in paths) ?await WarrantyScanner.compressFile(p),
      ];
      return WarrantyScan(const WarrantyGuess(), photos);
    });
