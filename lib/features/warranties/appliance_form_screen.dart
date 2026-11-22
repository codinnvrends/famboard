import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/warranty.dart';
import '../../services/warranty/warranty_scanner.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'cover_status.dart';
import 'photos.dart';
import 'warranty_add_flow.dart';

/// Add or edit an appliance. When opened from a scan, fields OCR filled are
/// marked "From photo" so the person knows what to check.
class ApplianceFormScreen extends ConsumerStatefulWidget {
  const ApplianceFormScreen({super.key, this.scan, this.applianceId});

  /// Photos and OCR guesses for a new appliance.
  final WarrantyScan? scan;

  /// Set when editing.
  final String? applianceId;

  @override
  ConsumerState<ApplianceFormScreen> createState() => _ApplianceFormScreenState();
}

class _ApplianceFormScreenState extends ConsumerState<ApplianceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serial = TextEditingController();
  final _store = TextEditingController();
  final _price = TextEditingController();
  final _invoice = TextEditingController();
  final _months = TextEditingController();
  final _extraProvider = TextEditingController();
  final _extraCost = TextEditingController();
  final _helpline = TextEditingController();
  final _centre = TextEditingController();
  final _centrePhone = TextEditingController();
  final _note = TextEditingController();

  DateTime? _purchaseDate;
  DateTime? _warrantyEnds;
  DateTime? _extraEnds;
  ExtraCoverKind _extraKind = ExtraCoverKind.extended;
  bool _hasExtra = false;
  final List<PhotoRef> _photos = [];

  /// Fields OCR filled in, shown with a "From photo" hint.
  final Set<String> _auto = {};
  Appliance? _existing;
  bool _loaded = false;
  bool _saving = false;

  bool get _editing => widget.applianceId != null;

  @override
  void initState() {
    super.initState();
    final scan = widget.scan;
    if (scan != null) {
      _photos.addAll(scan.photos.map(PhotoRef.fresh));
      final g = scan.guess;
      void fill(String key, TextEditingController c, String? v) {
        if (v == null || v.isEmpty) return;
        c.text = v;
        _auto.add(key);
      }

      fill('name', _name, g.name);
      fill('brand', _brand, g.brand);
      fill('model', _model, g.model);
      fill('serial', _serial, g.serial);
      fill('store', _store, g.store);
      fill('invoice', _invoice, g.invoiceNo);
      fill('helpline', _helpline, g.helpline);
      if (g.price != null) fill('price', _price, _num(g.price!));
      if (g.warrantyMonths != null) fill('months', _months, '${g.warrantyMonths}');
      if (g.purchaseDate != null) {
        _purchaseDate = g.purchaseDate;
        _auto.add('date');
      }
      if (g.extendedMonths != null && _purchaseDate != null) {
        _hasExtra = true;
        final base = g.warrantyMonths ?? 0;
        _extraEnds = addMonths(_purchaseDate!, base + g.extendedMonths!).subtract(const Duration(days: 1));
        _auto.add('extra');
      }
    }
    _loaded = !_editing;
  }

  void _loadExisting(Appliance a) {
    _existing = a;
    _name.text = a.name;
    _brand.text = a.brand ?? '';
    _model.text = a.model ?? '';
    _serial.text = a.serial ?? '';
    _store.text = a.store ?? '';
    _price.text = a.price == null ? '' : _num(a.price!);
    _invoice.text = a.invoiceNo ?? '';
    _months.text = a.warrantyMonths?.toString() ?? '';
    _extraProvider.text = a.extraProvider ?? '';
    _extraCost.text = a.extraCost == null ? '' : _num(a.extraCost!);
    _helpline.text = a.helpline ?? '';
    _centre.text = a.serviceCentre ?? '';
    _centrePhone.text = a.serviceCentrePhone ?? '';
    _note.text = a.note ?? '';
    _purchaseDate = a.purchaseDate;
    _warrantyEnds = a.warrantyEnds;
    _extraEnds = a.extraEnds;
    _extraKind = a.extraKind;
    _hasExtra = a.hasExtra;
    _photos
      ..clear()
      ..addAll(a.photos.map(PhotoRef.stored));
    _loaded = true;
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

  static double? _parseMoney(String s) => double.tryParse(s.replaceAll(RegExp(r'[,\s₹]'), ''));

  @override
  void dispose() {
    for (final c in [
      _name, _brand, _model, _serial, _store, _price, _invoice, _months, _extraProvider, _extraCost,
      _helpline, _centre, _centrePhone, _note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The maker's warranty end as currently filled in.
  Coverage get _previewCover => Appliance(
        id: '',
        familyId: '',
        name: '',
        purchaseDate: _purchaseDate,
        warrantyMonths: int.tryParse(_months.text.trim()),
        warrantyEnds: _warrantyEnds,
        updatedAt: DateTime.now(),
      ).warranty;

  String? _hint(String key) => _auto.contains(key) ? context.l10n.fromPhoto : null;

  Future<DateTime?> _pickDate(DateTime? initial, {DateTime? first, DateTime? last}) => showDatePicker(
        context: context,
        initialDate: initial ?? DateTime.now(),
        firstDate: first ?? DateTime(1990),
        lastDate: last ?? DateTime(DateTime.now().year + 30),
      );

  Future<void> _addPhotos({required bool camera}) async {
    final scanner = ref.read(servicesProvider).warrantyScanner;
    final paths = await pickWarrantyPhotos(context, scanner.bills, camera: camera);
    if (paths.isEmpty || !mounted) return;
    final more = await readMorePhotos(context, scanner, paths);
    if (more == null || !mounted) return;
    setState(() => _photos.addAll(more.photos.map(PhotoRef.fresh)));
  }

  Future<void> _save() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final services = ref.read(servicesProvider);
    final perms = ref.read(permsProvider);
    setState(() => _saving = true);
    try {
      final ids = <String>[
        for (final p in _photos)
          p.id ?? await services.blobs.put(session.familyId, p.bytes!),
      ];
      final draft = ApplianceDraft(
        name: _name.text,
        brand: _brand.text,
        model: _model.text,
        serial: _serial.text,
        purchaseDate: _purchaseDate,
        store: _store.text,
        price: _parseMoney(_price.text),
        invoiceNo: _invoice.text,
        warrantyMonths: int.tryParse(_months.text.trim()),
        warrantyEnds: _warrantyEnds,
        extraKind: _extraKind,
        extraProvider: _hasExtra ? _extraProvider.text : null,
        extraEnds: _hasExtra ? _extraEnds : null,
        extraCost: _hasExtra ? _parseMoney(_extraCost.text) : null,
        helpline: _helpline.text,
        serviceCentre: _centre.text,
        serviceCentrePhone: _centrePhone.text,
        note: _note.text,
        photos: ids,
      );
      final existing = _existing;
      if (existing != null) {
        await services.repo.updateAppliance(
          before: existing,
          draft: draft,
          memberId: session.memberId,
          includePrice: perms.canSeeMoney,
        );
        // Photos taken off the item are cleaned up after a grace day.
        await services.blobs.sweep(session.familyId);
        if (mounted) context.pop();
      } else {
        final id = await services.repo.addAppliance(
          familyId: session.familyId,
          memberId: session.memberId,
          draft: draft,
          includePrice: perms.canSeeMoney,
        );
        if (mounted) context.pushReplacement('/appliance/$id');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final perms = ref.watch(permsProvider);
    final session = ref.watch(sessionProvider);

    if (_editing && !_loaded && session != null) {
      final list = ref.watch(appliancesProvider(session.familyId)).value;
      final a = list?.where((x) => x.id == widget.applianceId).firstOrNull;
      if (a != null) _loadExisting(a);
    }
    final existing = _existing;
    if (_editing && existing == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final allowed = existing == null ? perms.canAddAppliance : perms.canEditAppliance(existing);
    if (!allowed) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(icon: Icons.lock_outline, title: l.warrantyEditLocked, body: l.warrantyEditLockedBody),
      );
    }
    final until = existing == null ? null : perms.ownEditUntil(existing);
    final cover = _previewCover;

    InputDecoration deco(String label, {String? key, String? hint, Widget? prefix}) => InputDecoration(
          labelText: label,
          helperText: key == null ? hint : (_hint(key) ?? hint),
          helperMaxLines: 2,
          prefixIcon: prefix,
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? l.warrantyEdit : l.warrantyNew),
        actions: [
          TextButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
          children: [
            if (_auto.isNotEmpty)
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: Icon(Icons.auto_awesome, color: theme.colorScheme.onSecondaryContainer),
                  title: Text(l.warrantyOcrFilled(_auto.length)),
                  subtitle: Text(l.warrantyOcrCheck),
                ),
              )
            else if (widget.scan != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.warrantyOcrNothing),
                ),
              ),
            if (until != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text(l.warrantyOwnEditUntil(TimeOfDay.fromDateTime(until).format(context))),
                  subtitle: Text(l.warrantyOnlyAdminsAfter),
                ),
              ),
            SectionHeader(l.warrantyPhotos),
            PhotoStrip(
              photos: _photos,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
              trailing: _AddPhotoTile(
                onCamera: ref.read(servicesProvider).billScanner.canUseCameraScanner
                    ? () => _addPhotos(camera: true)
                    : null,
                onGallery: () => _addPhotos(camera: false),
              ),
            ),
            SectionHeader(l.warrantyProduct),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco(l.warrantyName, key: 'name', hint: l.warrantyNameHint),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.warrantyNameNeeded : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brand,
                    textCapitalization: TextCapitalization.words,
                    decoration: deco(l.warrantyBrand, key: 'brand'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _model,
                    textCapitalization: TextCapitalization.characters,
                    decoration: deco(l.warrantyModel, key: 'model'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serial,
              textCapitalization: TextCapitalization.characters,
              decoration: deco(l.warrantySerial, key: 'serial'),
            ),
            SectionHeader(l.warrantyPurchase),
            _DateField(
              label: l.warrantyPurchaseDate,
              value: _purchaseDate,
              hint: _hint('date'),
              onPick: () async {
                final d = await _pickDate(_purchaseDate, last: DateTime.now());
                if (d != null) setState(() => _purchaseDate = d);
              },
              onClear: () => setState(() => _purchaseDate = null),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _store,
              textCapitalization: TextCapitalization.words,
              decoration: deco(l.warrantyStore, key: 'store'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (perms.canSeeMoney) ...[
                  Expanded(
                    child: TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: deco(l.warrantyPrice, key: 'price', prefix: const Icon(Icons.currency_rupee, size: 18)),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: TextFormField(
                    controller: _invoice,
                    textCapitalization: TextCapitalization.characters,
                    decoration: deco(l.warrantyInvoice, key: 'invoice'),
                  ),
                ),
              ],
            ),
            SectionHeader(l.warrantyCover),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in const [6, 12, 24, 36, 60])
                  ChoiceChip(
                    label: Text(m < 12 ? l.monthsShort(m) : l.yearsShort(m ~/ 12)),
                    selected: _warrantyEnds == null && _months.text.trim() == '$m',
                    onSelected: (_) => setState(() {
                      _months.text = '$m';
                      _warrantyEnds = null;
                      _auto.remove('months');
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _months,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: deco(l.warrantyMonths, key: 'months'),
              onChanged: (_) => setState(() => _warrantyEnds = null),
            ),
            const SizedBox(height: 8),
            _DateField(
              label: l.warrantyEndsOn,
              value: _warrantyEnds ?? cover.ends,
              hint: _warrantyEnds == null && cover.ends != null ? l.warrantyEndsComputed : null,
              onPick: () async {
                final d = await _pickDate(_warrantyEnds ?? cover.ends ?? _purchaseDate);
                if (d != null) setState(() => _warrantyEnds = d);
              },
              onClear: _warrantyEnds == null ? null : () => setState(() => _warrantyEnds = null),
            ),
            if (cover.ends != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Align(alignment: Alignment.centerLeft, child: CoverChip(cover))),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.warrantyHasExtra),
              subtitle: _auto.contains('extra') ? Text(l.fromPhoto) : null,
              value: _hasExtra,
              onChanged: (v) => setState(() => _hasExtra = v),
            ),
            if (_hasExtra) ...[
              SegmentedButton<ExtraCoverKind>(
                segments: [
                  ButtonSegment(value: ExtraCoverKind.extended, label: Text(l.coverExtended)),
                  ButtonSegment(value: ExtraCoverKind.amc, label: Text(l.coverAmc)),
                ],
                selected: {_extraKind},
                onSelectionChanged: (s) => setState(() => _extraKind = s.first),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _extraProvider,
                textCapitalization: TextCapitalization.words,
                decoration: deco(l.warrantyExtraProvider),
              ),
              const SizedBox(height: 12),
              _DateField(
                label: l.warrantyExtraEnds,
                value: _extraEnds,
                onPick: () async {
                  final d = await _pickDate(_extraEnds ?? cover.ends ?? _purchaseDate);
                  if (d != null) setState(() => _extraEnds = d);
                },
                onClear: () => setState(() => _extraEnds = null),
              ),
              if (perms.canSeeMoney) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _extraCost,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  decoration: deco(l.warrantyExtraCost, prefix: const Icon(Icons.currency_rupee, size: 18)),
                ),
              ],
            ],
            SectionHeader(l.warrantyService),
            TextFormField(
              controller: _helpline,
              keyboardType: TextInputType.phone,
              decoration: deco(l.warrantyHelpline, key: 'helpline', prefix: const Icon(Icons.support_agent, size: 20)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _centre,
              textCapitalization: TextCapitalization.words,
              decoration: deco(l.warrantyServiceCentre),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _centrePhone,
              keyboardType: TextInputType.phone,
              decoration: deco(l.warrantyServiceCentrePhone, prefix: const Icon(Icons.call_outlined, size: 20)),
            ),
            SectionHeader(l.noteLabel),
            TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: deco(l.warrantyNoteHint),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l.save),
            ),
            if (!perms.isAdmin && existing == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  l.warrantyAfterSaveNote,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.label, required this.value, required this.onPick, this.onClear, this.hint});

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback? onClear;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: hint,
          helperMaxLines: 2,
          prefixIcon: const Icon(Icons.event_outlined, size: 20),
          suffixIcon: value != null && onClear != null
              ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: onClear, tooltip: context.l10n.clear)
              : null,
        ),
        child: Text(value == null ? '' : formatLongDate(context, value!)),
      ),
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onCamera, required this.onGallery});

  final VoidCallback? onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      width: 75,
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: PopupMenuButton<bool>(
          tooltip: l.warrantyAddPhoto,
          onSelected: (camera) => camera ? onCamera?.call() : onGallery(),
          itemBuilder: (_) => [
            if (onCamera != null) PopupMenuItem(value: true, child: Text(l.warrantyScanCamera)),
            PopupMenuItem(value: false, child: Text(l.warrantyScanGallery)),
          ],
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 4),
                Text(l.warrantyAddPhoto, style: theme.textTheme.labelSmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
