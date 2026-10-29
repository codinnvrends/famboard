import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../services/text_extractor.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'entry_form.dart';

/// Turns shared or pasted text into a quick-add prefill: a bill when the
/// text looks like a bill SMS (spec FR-43), otherwise the text as a title.
EntryPrefill prefillFromText(SmsBillParser parser, String text) {
  final bill = parser.parse(text);
  if (bill != null) {
    return EntryPrefill(
      title: bill.title,
      type: EntryType.bill,
      categoryId: bill.categoryId,
      amount: bill.amount,
      dueAt: bill.dueAt,
      note: text.length > 300 ? '${text.substring(0, 300)}…' : text,
    );
  }
  final firstLine = text.split('\n').first.trim();
  return EntryPrefill(
    title: firstLine.length > 80 ? firstLine.substring(0, 80) : firstLine,
    note: text.length > firstLine.length ? text : null,
  );
}

/// Asks for pasted bill text, then opens quick add with what it found.
Future<void> showSmsPaste(BuildContext context) async {
  final l = context.l10n;
  final controller = TextEditingController();
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (clip?.text != null && clip!.text!.length > 20) controller.text = clip.text!;
  if (!context.mounted) return;
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.pasteSmsTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 4,
        maxLines: 8,
        decoration: InputDecoration(hintText: l.pasteSmsHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(l.continueAction)),
      ],
    ),
  );
  if (text == null || text.trim().isEmpty || !context.mounted) return;
  await openFromSharedText(context, text);
}

/// Opens quick add for text shared into the app or pasted by the user.
Future<void> openFromSharedText(BuildContext context, String text) async {
  final parser = ProviderScope.containerOf(context, listen: false).read(servicesProvider).smsParser;
  if (parser.parse(text) == null) showSnack(context, context.l10n.noBillFound);
  await showQuickAdd(context, prefill: prefillFromText(parser, text));
}
