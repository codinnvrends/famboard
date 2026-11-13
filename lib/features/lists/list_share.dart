import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models.dart';
import '../../services/lists/list_export.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

enum ListFormat { text, pdf, csv }

/// Bottom sheet: send a list as a WhatsApp-ready message, a PDF or a CSV,
/// or save the PDF/CSV to the phone.
Future<void> showShareList(BuildContext context, SavedList list, List<ListItem> items) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => _ShareSheet(list: list, items: items),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.list, required this.items});
  final SavedList list;
  final List<ListItem> items;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  bool _prices = false;
  bool _onlyRemaining = false;

  bool get _hasPrices => widget.items.any((i) => i.amount != null);
  bool get _hasChecked => widget.items.any((i) => i.checked);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(l.listShareTitle, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (_hasPrices)
              SwitchListTile(
                title: Text(l.listSharePrices),
                value: _prices,
                onChanged: (v) => setState(() => _prices = v),
              ),
            if (_hasChecked)
              SwitchListTile(
                title: Text(l.listShareOnlyRemaining),
                value: _onlyRemaining,
                onChanged: (v) => setState(() => _onlyRemaining = v),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: Text(l.listShareText),
              subtitle: Text(l.listShareTextBody),
              onTap: () => _run(ListFormat.text, save: false),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: Text(l.listSharePdf),
              trailing: IconButton(
                tooltip: l.listSaveToPhone,
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _run(ListFormat.pdf, save: true),
              ),
              onTap: () => _run(ListFormat.pdf, save: false),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(l.listShareCsv),
              trailing: IconButton(
                tooltip: l.listSaveToPhone,
                icon: const Icon(Icons.download_outlined),
                onPressed: () => _run(ListFormat.csv, save: true),
              ),
              onTap: () => _run(ListFormat.csv, save: false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<ListItem> get _items => _onlyRemaining ? widget.items.where((i) => !i.checked).toList() : widget.items;

  Future<void> _run(ListFormat format, {required bool save}) async {
    final l = context.l10n;
    const export = ListExport();
    final list = widget.list;
    try {
      if (format == ListFormat.text) {
        await SharePlus.instance.share(ShareParams(text: export.text(list, _items, withPrices: _prices)));
        return;
      }
      final stem = ListExport.fileStem(list.name, list.billDate ?? list.createdAt);
      final (String name, Uint8List bytes, String mime) = switch (format) {
        ListFormat.pdf => (
          '$stem.pdf',
          await export.pdf(
            list,
            _items,
            regular: await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf'),
            bold: await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf'),
            withPrices: _prices,
          ),
          'application/pdf',
        ),
        _ => (
          '$stem.csv',
          // BOM so Excel shows Hindi text correctly.
          Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(export.csv(list, _items))]),
          'text/csv',
        ),
      };
      if (save) {
        final uri = await FilePicker.saveFile(
          fileName: name,
          bytes: bytes,
          mimeType: mime,
          dialogTitle: l.listSaveToPhone,
        );
        if (uri != null && mounted) {
          showSnack(context, l.listSaved);
          Navigator.pop(context);
        }
      } else {
        final dir = await getTemporaryDirectory();
        final file = File(p.join(dir.path, name));
        await file.writeAsBytes(bytes, flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: mime, name: name)],
            subject: list.name,
          ),
        );
      }
    } catch (_) {
      if (mounted) showSnack(context, l.genericError);
    }
  }
}
