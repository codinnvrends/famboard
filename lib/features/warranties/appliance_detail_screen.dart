import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../domain/warranty.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../entries/entry_form.dart';
import 'cover_status.dart';
import 'photos.dart';
import 'service_visit_sheet.dart';

/// Everything about one appliance: photos of its paperwork, cover, details
/// to read out to a service centre, repairs and service history.
class ApplianceDetailScreen extends ConsumerWidget {
  const ApplianceDetailScreen({super.key, required this.applianceId});

  final String applianceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final perms = ref.watch(permsProvider);
    final appliances = ref.watch(appliancesProvider(session.familyId));
    final a = appliances.value?.where((x) => x.id == applianceId).firstOrNull;
    if (a == null) {
      return Scaffold(
        appBar: AppBar(),
        body: appliances.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.delete_outline, title: l.warrantyGone),
      );
    }
    final names = ref.watch(memberNamesProvider);
    final visits = (ref.watch(serviceVisitsProvider(session.familyId)).value ?? const <ServiceVisit>[])
        .where((v) => v.applianceId == a.id)
        .toList();
    final repairs = (ref.watch(entriesProvider(session.familyId)).value ?? const <Entry>[])
        .where((e) => e.applianceId == a.id)
        .toList()
      ..sort((x, y) => y.updatedAt.compareTo(x.updatedAt));
    final canEdit = perms.canEditAppliance(a);
    final until = perms.ownEditUntil(a);
    final extra = a.extra;

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name, overflow: TextOverflow.ellipsis),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: l.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/appliance/${a.id}/edit'),
            ),
          if (perms.canDeleteAppliance(a))
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(context, ref, a),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
        children: [
          if (a.photos.isNotEmpty)
            PhotoStrip(
              photos: [for (final id in a.photos) PhotoRef.stored(id, kind: a.photoKinds[id] ?? PhotoKind.other)],
              height: 140,
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.warrantyMaker, style: theme.textTheme.labelLarge),
                  const SizedBox(height: 6),
                  CoverChip(a.warranty),
                  if (a.warranty.ends == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(l.warrantyAddEndHint, style: theme.textTheme.bodySmall),
                    ),
                  if (a.hasExtra) ...[
                    const SizedBox(height: 12),
                    Text(
                      [extraKindLabel(context, a.extraKind), a.extraProvider].whereType<String>().join(' · '),
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 6),
                    if (extra != null) CoverChip(extra),
                    if (perms.canSeeMoney && a.extraCost != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(l.warrantyExtraCostIs(formatMoney(a.extraCost!)), style: theme.textTheme.bodySmall),
                      ),
                  ],
                ],
              ),
            ),
          ),
          if (until != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.warrantyOwnEditUntil(TimeOfDay.fromDateTime(until).format(context)),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else if (!canEdit)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                l.warrantyAdminsOnly,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          SectionHeader(l.warrantyDetails),
          Card(
            child: Column(
              children: [
                _Row(Icons.business_outlined, l.warrantyBrand, a.brand),
                _Row(Icons.tag, l.warrantyModel, a.model, copy: true),
                _Row(Icons.qr_code_2, l.warrantySerial, a.serial, copy: true),
                _Row(Icons.event_outlined, l.warrantyPurchaseDate,
                    a.purchaseDate == null ? null : formatLongDate(context, a.purchaseDate!)),
                _Row(Icons.storefront_outlined, l.warrantyStore, a.store),
                if (perms.canSeeMoney)
                  _Row(Icons.currency_rupee, l.warrantyPrice, a.price == null ? null : formatMoney(a.price!)),
                _Row(Icons.receipt_outlined, l.warrantyInvoice, a.invoiceNo, copy: true),
                if (a.createdBy != null)
                  _Row(Icons.person_outline, l.warrantyAddedBy, [
                    names[a.createdBy] ?? '?',
                    if (a.createdAt != null) formatLongDate(context, a.createdAt!),
                  ].join(' · ')),
              ],
            ),
          ),
          if (a.helpline != null || a.serviceCentre != null || a.serviceCentrePhone != null) ...[
            SectionHeader(l.warrantyService),
            Card(
              child: Column(
                children: [
                  if (a.helpline != null)
                    ListTile(
                      leading: const Icon(Icons.support_agent),
                      title: Text(l.warrantyHelpline),
                      subtitle: Text(a.helpline!),
                      trailing: const Icon(Icons.call),
                      onTap: () => _call(context, a.helpline!),
                    ),
                  if (a.serviceCentre != null || a.serviceCentrePhone != null)
                    ListTile(
                      leading: const Icon(Icons.home_repair_service_outlined),
                      title: Text(a.serviceCentre ?? l.warrantyServiceCentre),
                      subtitle: a.serviceCentrePhone == null ? null : Text(a.serviceCentrePhone!),
                      trailing: a.serviceCentrePhone == null ? null : const Icon(Icons.call),
                      onTap: a.serviceCentrePhone == null ? null : () => _call(context, a.serviceCentrePhone!),
                    ),
                ],
              ),
            ),
          ],
          SectionHeader(
            l.warrantyRepairs,
            count: repairs.where((e) => e.isOpen).isEmpty ? null : repairs.where((e) => e.isOpen).length,
            trailing: perms.canAddEntries
                ? TextButton.icon(
                    icon: const Icon(Icons.build_outlined, size: 18),
                    label: Text(l.warrantyReportRepair),
                    onPressed: () => showQuickAdd(
                      context,
                      prefill: EntryPrefill(
                        type: EntryType.repair,
                        title: a.name,
                        applianceId: a.id,
                        note: a.coveredOn(DateTime.now()) ? l.warrantyRepairNote(coverLabel(context, a.bestCover)) : null,
                      ),
                    ),
                  )
                : null,
          ),
          if (repairs.isEmpty)
            Text(l.warrantyNoRepairs, style: theme.textTheme.bodySmall)
          else
            for (final e in repairs)
              Padding(padding: const EdgeInsets.only(bottom: 8), child: EntryTile(e)),
          SectionHeader(
            l.warrantyHistory,
            count: visits.isEmpty ? null : visits.length,
            trailing: perms.canAddServiceVisit
                ? TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l.warrantyAddVisit),
                    onPressed: () => showServiceVisitSheet(context, a),
                  )
                : null,
          ),
          if (visits.isEmpty)
            Text(l.warrantyNoVisits, style: theme.textTheme.bodySmall)
          else
            Card(
              child: Column(
                children: [
                  for (final v in visits)
                    ListTile(
                      leading: Icon(
                        v.covered ? Icons.verified_user_outlined : Icons.handyman_outlined,
                        color: v.covered ? theme.colorScheme.primary : null,
                      ),
                      title: Text(v.issue),
                      subtitle: Text([
                        formatLongDate(context, v.date),
                        if (v.technician != null) v.technician!,
                        if (v.covered) l.visitCovered,
                        if (perms.canSeeMoney && v.cost != null) formatMoney(v.cost!),
                      ].join(' · ')),
                      onTap: perms.canEditServiceVisit(v) ? () => showServiceVisitSheet(context, a, visit: v) : null,
                    ),
                ],
              ),
            ),
          if (a.note != null) ...[
            SectionHeader(l.noteLabel),
            Text(a.note!),
          ],
        ],
      ),
    );
  }

  Future<void> _call(BuildContext context, String number) async {
    final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final ok = await launchUrl(Uri(scheme: 'tel', path: digits));
    if (!ok && context.mounted) showSnack(context, context.l10n.linkOpenFailed(number));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Appliance a) async {
    final l = context.l10n;
    if (!await confirm(
      context,
      title: l.warrantyDeleteTitle,
      body: l.warrantyDeleteBody(a.name),
      action: l.delete,
      destructive: true,
    )) {
      return;
    }
    final services = ref.read(servicesProvider);
    await services.repo.deleteAppliance(a);
    await services.blobs.sweep(a.familyId);
    if (context.mounted) {
      context.pop();
      showSnack(context, l.warrantyDeleted(a.name));
    }
  }
}

class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.copy = false});

  final IconData icon;
  final String label;
  final String? value;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null || v.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label, style: Theme.of(context).textTheme.labelMedium),
      subtitle: SelectableText(v, style: Theme.of(context).textTheme.bodyLarge),
      trailing: copy
          ? IconButton(
              tooltip: context.l10n.copy,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: v));
                showSnack(context, context.l10n.copied);
              },
            )
          : null,
    );
  }
}
