import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/warranty.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

/// Add or edit one service / repair visit.
Future<void> showServiceVisitSheet(BuildContext context, Appliance appliance, {ServiceVisit? visit}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _VisitForm(appliance: appliance, visit: visit),
    );

class _VisitForm extends ConsumerStatefulWidget {
  const _VisitForm({required this.appliance, this.visit});

  final Appliance appliance;
  final ServiceVisit? visit;

  @override
  ConsumerState<_VisitForm> createState() => _VisitFormState();
}

class _VisitFormState extends ConsumerState<_VisitForm> {
  late final _issue = TextEditingController(text: widget.visit?.issue ?? '');
  late final _tech = TextEditingController(text: widget.visit?.technician ?? '');
  late final _cost = TextEditingController(
    text: widget.visit?.cost == null ? '' : widget.visit!.cost!.toStringAsFixed(widget.visit!.cost! % 1 == 0 ? 0 : 2),
  );
  late final _note = TextEditingController(text: widget.visit?.note ?? '');
  late DateTime _date = widget.visit?.date ?? DateTime.now();
  late bool _covered = widget.visit?.covered ?? widget.appliance.coveredOn(DateTime.now());
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _issue.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _issue.dispose();
    _tech.dispose();
    _cost.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final session = ref.read(sessionProvider);
    if (session == null || _issue.text.trim().isEmpty) return;
    final perms = ref.read(permsProvider);
    setState(() => _saving = true);
    await ref.read(servicesProvider).repo.saveServiceVisit(
          familyId: session.familyId,
          memberId: session.memberId,
          applianceId: widget.appliance.id,
          id: widget.visit?.id,
          date: _date,
          issue: _issue.text,
          technician: _tech.text,
          cost: double.tryParse(_cost.text.replaceAll(',', '')),
          covered: _covered,
          note: _note.text,
          includeCost: perms.canSeeMoney,
        );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final v = widget.visit;
    final session = ref.read(sessionProvider);
    if (v == null || session == null) return;
    if (!await confirm(context, title: l.visitDelete, action: l.delete, destructive: true)) return;
    await ref.read(servicesProvider).repo.deleteServiceVisit(session.familyId, v.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final perms = ref.watch(permsProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.visit == null ? l.warrantyAddVisit : l.visitEdit, style: Theme.of(context).textTheme.titleLarge),
            Text(widget.appliance.name, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _issue,
              autofocus: widget.visit == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.visitIssue, hintText: l.visitIssueHint),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l.visitDate),
              subtitle: Text(formatLongDate(context, _date)),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(1990),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
            ),
            TextField(
              controller: _tech,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.visitTechnician),
            ),
            if (perms.canSeeMoney) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _cost,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(labelText: l.visitCost, prefixIcon: const Icon(Icons.currency_rupee, size: 18)),
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.visitCoveredQuestion),
              value: _covered,
              onChanged: (v) => setState(() => _covered = v),
            ),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.noteLabel),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.visit != null)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.delete),
                    onPressed: _saving ? null : _delete,
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _issue.text.trim().isEmpty || _saving ? null : _save,
                  child: Text(l.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
