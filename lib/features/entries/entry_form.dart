import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/famboard_repository.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../services/categorizer/categorizer.dart';
import '../../services/recurrence.dart';
import '../../services/text_extractor.dart';
import '../../services/voice.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'category_picker.dart';

/// Prefill for the form, e.g. from a shared bill SMS.
class EntryPrefill {
  const EntryPrefill({
    this.title,
    this.type,
    this.categoryId,
    this.amount,
    this.dueAt,
    this.note,
  });

  final String? title;
  final EntryType? type;
  final String? categoryId;
  final double? amount;
  final DateTime? dueAt;
  final String? note;
}

/// Opens the quick-add sheet.
Future<void> showQuickAdd(BuildContext context, {EntryPrefill? prefill, bool voice = false}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => EntryForm(prefill: prefill, startWithVoice: voice),
  );
}

/// Opens the edit sheet for [entry].
Future<void> showEditEntry(BuildContext context, Entry entry) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => EntryForm(existing: entry),
  );
}

/// Add/edit form. In add mode it categorizes live as you type or speak,
/// pulls out amounts, quantities and dates, and warns about duplicates.
class EntryForm extends ConsumerStatefulWidget {
  const EntryForm({super.key, this.existing, this.prefill, this.startWithVoice = false});

  final Entry? existing;
  final EntryPrefill? prefill;
  final bool startWithVoice;

  @override
  ConsumerState<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<EntryForm> {
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _amount = TextEditingController();
  final _quantity = TextEditingController();
  final _unit = TextEditingController();
  final _titleFocus = FocusNode();

  late EntryType _type;
  late String _categoryId;
  Priority _priority = Priority.normal;
  DateTime? _due;
  String? _assignee;
  String? _rrule;
  int? _leadDays;

  bool _typeLocked = false;
  bool _categoryLocked = false;
  bool _expanded = false;
  bool _saving = false;
  bool _listening = false;
  String? _voiceMessage;
  String _voiceLocale = 'en_IN';
  Categorization? _suggestion;
  Extraction? _extraction;

  bool get _isEdit => widget.existing != null;
  late final VoiceInput _voice = ref.read(servicesProvider).voice;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final p = widget.prefill;
    if (e != null) {
      _title.text = e.title;
      _note.text = e.note ?? '';
      _amount.text = e.amount == null ? '' : _num(e.amount!);
      _quantity.text = e.quantity == null ? '' : _num(e.quantity!);
      _unit.text = e.unit ?? '';
      _type = e.type;
      _categoryId = e.categoryId;
      _priority = e.priority;
      _due = e.dueAt;
      _assignee = e.assigneeId;
      _rrule = e.rrule;
      _leadDays = e.leadDays;
      _typeLocked = _categoryLocked = true;
      _expanded = true;
      _title.addListener(() => setState(() {}));
    } else {
      _type = p?.type ?? EntryType.needToBuy;
      _categoryId = p?.categoryId ?? defaultCategoryForType[_type]!;
      _typeLocked = p?.type != null;
      _categoryLocked = p?.categoryId != null;
      _title.text = p?.title ?? '';
      _note.text = p?.note ?? '';
      if (p?.amount != null) _amount.text = _num(p!.amount!);
      _due = p?.dueAt;
      if (p?.amount != null || p?.dueAt != null) _expanded = true;
      _title.addListener(_onTitleChanged);
      if (_title.text.isNotEmpty) _onTitleChanged();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _voiceLocale = context.locale.languageCode == 'hi' ? 'hi_IN' : 'en_IN';
      if (widget.startWithVoice) {
        _toggleVoice();
      } else if (!_isEdit) {
        _titleFocus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final c in [_title, _note, _amount, _quantity, _unit]) {
      c.dispose();
    }
    _titleFocus.dispose();
    if (_listening) _voice.stop();
    super.dispose();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void _onTitleChanged() {
    final services = ref.read(servicesProvider);
    final session = ref.read(sessionProvider);
    final overrides = session == null
        ? const <KeywordOverride>[]
        : ref.read(overridesProvider(session.familyId)).value ?? const [];
    final text = _title.text;
    final extraction = services.extractor.extract(text, type: _typeLocked ? _type : null);
    final suggestion = services.categorizer.categorize(
      extraction.title.isEmpty ? text : extraction.title,
      overrides: overrides,
    );
    // A bill-like title may carry a bare amount ("electricity bill 1250").
    final refined = !_typeLocked && suggestion.type == EntryType.bill
        ? services.extractor.extract(text, type: EntryType.bill)
        : extraction;
    setState(() {
      _suggestion = suggestion;
      _extraction = refined.hasDetails ? refined : null;
      if (!_typeLocked) _type = suggestion.type;
      if (!_categoryLocked) _categoryId = suggestion.categoryId;
    });
  }

  Future<void> _toggleVoice() async {
    final voice = _voice;
    if (_listening) {
      await voice.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _voiceMessage = null;
    });
    final problem = await voice.listen(
      localeId: _voiceLocale,
      onText: (text, isFinal) {
        if (!mounted) return;
        _title.text = text;
        _title.selection = TextSelection.collapsed(offset: text.length);
        if (isFinal) setState(() => _listening = false);
      },
      onProblem: (p) {
        if (!mounted) return;
        setState(() {
          _listening = false;
          _voiceMessage = _voiceText(p);
        });
      },
    );
    if (problem != null && mounted) {
      setState(() {
        _listening = false;
        _voiceMessage = _voiceText(problem);
      });
    }
  }

  String _voiceText(VoiceProblem p) => switch (p) {
        VoiceProblem.needsInternet => context.l10n.voiceNeedsInternet,
        VoiceProblem.permission => context.l10n.voicePermission,
        VoiceProblem.noMatch => context.l10n.voiceNoMatch,
        VoiceProblem.unavailable => context.l10n.voiceUnavailable,
        VoiceProblem.other => context.l10n.voiceNoMatch,
      };

  Future<void> _pickCategory() async {
    final id = await pickCategory(context, current: _categoryId);
    if (id == null) return;
    setState(() {
      _categoryId = id;
      _categoryLocked = true;
    });
  }

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? _extraction?.dueAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _pickRepeat() async {
    final l = context.l10n;
    final anchor = _due ?? _extraction?.dueAt ?? DateTime.now();
    final options = <(String, String?)>[
      (l.repeatNever, null),
      (l.repeatDaily, RecurrenceRule.daily().toString()),
      (l.repeatWeekly, RecurrenceRule.weekly(anchor.weekday).toString()),
      (l.repeatMonthly, RecurrenceRule.monthly(anchor.day).toString()),
      (l.repeatQuarterly, RecurrenceRule.quarterly(anchor.day).toString()),
      (l.repeatYearly, RecurrenceRule.yearly().toString()),
      (l.repeatEveryNDays, 'custom'),
    ];
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (label, value) in options)
              ListTile(
                title: Text(value == null || value == 'custom' ? label : describeRule(context, value)),
                trailing: value == _rrule ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, value ?? ''),
              ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    if (chosen == 'custom') {
      if (!mounted) return;
      final days = await _askNumber(l.repeatEveryNDays, l.daysLabel, 10);
      if (days != null && days > 0) {
        setState(() => _rrule = RecurrenceRule.everyNDays(days).toString());
      }
      return;
    }
    setState(() {
      _rrule = chosen.isEmpty ? null : chosen;
      if (_rrule != null && _due == null) _due = anchor;
    });
  }

  Future<int?> _askNumber(String title, String label, int initial) async {
    final c = TextEditingController(text: '$initial');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(context.l10n.save)),
        ],
      ),
    );
    return ok == true ? int.tryParse(c.text) : null;
  }

  Future<void> _save() async {
    final l = context.l10n;
    final services = ref.read(servicesProvider);
    final session = ref.read(sessionProvider);
    final perms = ref.read(permsProvider);
    if (session == null || _saving) return;
    final ex = _isEdit ? null : _extraction;
    final title = (ex != null && ex.title.isNotEmpty ? ex.title : _title.text).trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);

    final amount = double.tryParse(_amount.text.replaceAll(',', '')) ?? ex?.amount;
    final quantity = double.tryParse(_quantity.text) ?? ex?.quantity;
    final unit = _unit.text.trim().isNotEmpty ? _unit.text.trim() : ex?.unit;
    final due = _due ?? ex?.dueAt;
    final suggestedCategory = _suggestion?.categoryId;
    final userCorrected = _categoryLocked &&
        suggestedCategory != null &&
        suggestedCategory != _categoryId &&
        !_isEdit;
    final editCorrected = _isEdit && widget.existing!.categoryId != _categoryId;

    try {
      if (_isEdit) {
        await services.repo.updateEntry(
          before: widget.existing!,
          memberId: session.memberId,
          changes: {
            'title': title,
            'type': _type.code,
            'categoryId': _categoryId,
            'priority': _priority.code,
            'quantity': quantity,
            'unit': unit,
            if (perms.canSeeAmounts) 'amount': amount,
            'dueAt': due?.toIso8601String(),
            'assigneeId': _assignee,
            'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
            'rrule': _rrule,
            'leadDays': _leadDays,
          },
        );
      } else {
        await services.repo.addEntry(
          familyId: session.familyId,
          memberId: session.memberId,
          draft: EntryDraft(
            title: title,
            type: _type,
            categoryId: _categoryId,
            priority: _priority,
            quantity: quantity,
            unit: unit,
            amount: perms.canSeeAmounts ? amount : null,
            dueAt: due,
            assigneeId: _assignee,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            rrule: _rrule,
            leadDays: _leadDays,
          ),
        );
      }
      if (userCorrected || editCorrected) {
        await services.repo.learnCategory(
          familyId: session.familyId,
          title: title,
          categoryId: _categoryId,
          type: _type,
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(userCorrected || editCorrected ? l.learnedCategory : l.entryAdded),
        ));
    } catch (e) {
      if (mounted) showSnack(context, l.genericError);
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final perms = ref.watch(permsProvider);
    final members = session == null
        ? const <Member>[]
        : (ref.watch(membersProvider(session.familyId)).value ?? const [])
            .where((m) => !m.removed)
            .toList();
    final custom = session == null
        ? const <CustomCategory>[]
        : ref.watch(customCategoriesProvider(session.familyId)).value ?? const [];
    final cat = categoryById(_categoryId, custom: custom);
    final duplicates = _isEdit || session == null
        ? const <Entry>[]
        : ref.read(servicesProvider).repo.findDuplicates(
              ref.watch(entriesProvider(session.familyId)).value ?? const [],
              _extraction?.title.isNotEmpty == true ? _extraction!.title : _title.text,
            );
    final ex = _extraction;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_isEdit ? l.edit : l.quickAddTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              focusNode: _titleFocus,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              minLines: 1,
              maxLines: 3,
              style: theme.textTheme.titleMedium,
              onSubmitted: (_) => _save(),
              decoration: InputDecoration(
                hintText: l.quickAddHint,
                suffixIcon: _isEdit
                    ? null
                    : IconButton(
                        tooltip: _listening ? l.voiceListening : null,
                        icon: Icon(_listening ? Icons.stop_circle : Icons.mic_none),
                        color: _listening ? theme.colorScheme.error : theme.colorScheme.primary,
                        onPressed: _toggleVoice,
                      ),
              ),
            ),
            if (_listening || _voiceMessage != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (_listening) ...[
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                    Text(l.voiceListening),
                    const Spacer(),
                  ] else
                    Expanded(
                      child: Text(
                        _voiceMessage!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                      ),
                    ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: 'en_IN', label: Text(l.voiceEnglish)),
                      ButtonSegment(value: 'hi_IN', label: Text(l.voiceHindi)),
                    ],
                    selected: {_voiceLocale},
                    onSelectionChanged: (s) async {
                      setState(() => _voiceLocale = s.first);
                      if (_listening) {
                        await ref.read(servicesProvider).voice.stop();
                        _listening = false;
                        await _toggleVoice();
                      }
                    },
                  ),
                ],
              ),
            ],
            if (duplicates.isNotEmpty) ...[
              const SizedBox(height: 8),
              Material(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.content_copy_outlined),
                  title: Text(l.duplicateWarning(duplicates.first.title)),
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/entry/${duplicates.first.id}');
                    },
                    child: Text(l.viewExisting),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final t in EntryType.values) ...[
                    ChoiceChip(
                      avatar: Icon(t.icon, size: 18),
                      label: Text(t.label(l)),
                      selected: _type == t,
                      onSelected: (_) => setState(() {
                        _type = t;
                        _typeLocked = true;
                        if (!_categoryLocked) {
                          _categoryId = _suggestion?.type == t
                              ? _suggestion!.categoryId
                              : defaultCategoryForType[t]!;
                        }
                      }),
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InputChip(
                  avatar: Icon(cat.icon, color: cat.color, size: 18),
                  label: Text(cat.name(context.locale)),
                  onPressed: _pickCategory,
                ),
                if (ex?.quantity != null && _quantity.text.isEmpty)
                  Chip(
                    avatar: const Icon(Icons.scale_outlined, size: 16),
                    label: Text(formatQuantity(ex!.quantity, ex.unit)),
                  ),
                if (ex?.amount != null && _amount.text.isEmpty && perms.canSeeAmounts)
                  Chip(
                    avatar: const Icon(Icons.currency_rupee, size: 16),
                    label: Text(formatMoney(ex!.amount!)),
                  ),
                if (ex?.dueAt != null && _due == null)
                  Chip(
                    avatar: const Icon(Icons.event_outlined, size: 16),
                    label: Text(formatDate(context, ex!.dueAt!)),
                  ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(_expanded ? l.fewerDetails : l.moreDetails),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),
            if (_expanded) ..._details(context, members, perms.canSeeAmounts),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_isEdit ? Icons.check : Icons.add),
              label: Text(_isEdit ? l.save : l.add),
              onPressed: _title.text.trim().isEmpty || _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _details(BuildContext context, List<Member> members, bool canSeeAmounts) {
    final l = context.l10n;
    return [
      Text(l.priorityLabel, style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 6),
      SegmentedButton<Priority>(
        showSelectedIcon: false,
        segments: [
          for (final p in Priority.values) ButtonSegment(value: p, label: Text(p.label(l))),
        ],
        selected: {_priority},
        onSelectionChanged: (s) => setState(() => _priority = s.first),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _quantity,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: l.quantityLabel),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _unit,
              decoration: InputDecoration(labelText: l.unitLabel),
            ),
          ),
          if (canSeeAmounts) ...[
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: l.amountLabel),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ],
      ),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_outlined),
        title: Text(l.dueLabel),
        subtitle: Text(
          _due != null
              ? formatDate(context, _due!)
              : _extraction?.dueAt != null
                  ? formatDate(context, _extraction!.dueAt!)
                  : l.noDueDate,
        ),
        trailing: _due == null
            ? null
            : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _due = null)),
        onTap: _pickDue,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.repeat),
        title: Text(l.repeatLabel),
        subtitle: Text(describeRule(context, _rrule)),
        onTap: _pickRepeat,
      ),
      if (_due != null || _rrule != null || _extraction?.dueAt != null)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(l.reminderLabel),
          subtitle: Text(_leadDays == null || _leadDays == 0 ? l.reminderNone : l.reminderDaysBefore(_leadDays!)),
          onTap: () async {
            final n = await _askNumber(l.reminderLabel, l.daysLabel, _leadDays ?? 3);
            if (n != null) setState(() => _leadDays = n);
          },
        ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.person_outline),
        title: Text(l.assigneeLabel),
        trailing: DropdownButton<String?>(
          value: members.any((m) => m.id == _assignee) ? _assignee : null,
          underline: const SizedBox.shrink(),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(l.nobody)),
            for (final m in members) DropdownMenuItem<String?>(value: m.id, child: Text(m.name)),
          ],
          onChanged: (v) => setState(() => _assignee = v),
        ),
      ),
      TextField(
        controller: _note,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: l.noteLabel),
      ),
    ];
  }
}
