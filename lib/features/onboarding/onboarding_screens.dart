import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/invite.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../home/share_handler.dart';
import '../settings/backup_flow.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with ShareHandler {
  /// Without a family there's nowhere to add text; only backups apply here.
  @override
  bool get acceptsText => false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final hasFamily = (ref.watch(familiesProvider).value ?? const []).isNotEmpty;
    return Scaffold(
      appBar: hasFamily ? AppBar() : null,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FamTheme.teal,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.home_work_outlined, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 24),
              Text(
                l.appTitle,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: FamTheme.teal),
              ),
              const SizedBox(height: 8),
              Text(l.welcomeTitle, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Text(l.welcomeBody, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const Spacer(flex: 2),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                icon: const Icon(Icons.add_home_outlined),
                label: Text(l.createFamily),
                onPressed: () => context.push('/welcome/create'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l.joinFamily),
                onPressed: () => context.push('/welcome/join'),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.settings_backup_restore),
                label: Text(l.backupRestore),
                onPressed: () => pickAndRestoreBackup(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateFamilyScreen extends ConsumerStatefulWidget {
  const CreateFamilyScreen({super.key});

  @override
  ConsumerState<CreateFamilyScreen> createState() => _CreateFamilyScreenState();
}

class _CreateFamilyScreenState extends ConsumerState<CreateFamilyScreen> {
  final _family = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;

  bool get _valid => _family.text.trim().isNotEmpty && _name.text.trim().isNotEmpty;

  Future<void> _create() async {
    if (!_valid || _busy) return;
    setState(() => _busy = true);
    await ref.read(servicesProvider).repo.createFamily(
          familyName: _family.text,
          myName: _name.text,
        );
    await ref.read(servicesProvider).families.refresh();
    if (mounted) context.go('/today');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.createFamily)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(
            controller: _family,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.familyNameLabel, hintText: l.familyNameHint),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l.yourNameLabel, hintText: l.yourNameHint),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _create(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _valid && !_busy ? _create : null,
            child: Text(l.createFamilyAction),
          ),
        ],
      ),
    );
  }
}

class JoinFamilyScreen extends ConsumerStatefulWidget {
  const JoinFamilyScreen({super.key});

  @override
  ConsumerState<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends ConsumerState<JoinFamilyScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _scanner = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  FamilyInvite? _invite;
  bool _paste = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  void _accept(String raw) {
    final l = context.l10n;
    try {
      final invite = FamilyInvite.decode(raw);
      setState(() {
        if (invite.isExpired()) {
          _error = l.inviteExpired;
        } else {
          _invite = invite;
          _error = null;
        }
      });
    } on FormatException {
      setState(() => _error = l.inviteInvalid);
    }
  }

  Future<void> _join() async {
    final invite = _invite;
    if (invite == null || (!invite.isReturning && _name.text.trim().isEmpty) || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(servicesProvider).repo.joinFamily(invite, myName: _name.text);
      await ref.read(servicesProvider).families.refresh();
      if (!mounted) return;
      showSnack(context, context.l10n.joinedWaitingSync);
      context.go('/family');
    } catch (e) {
      setState(() {
        _busy = false;
        _error = context.l10n.inviteExpired;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final invite = _invite;

    return Scaffold(
      appBar: AppBar(title: Text(l.joinFamily)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (invite == null) ...[
            Text(l.scanInviteTitle, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(l.scanInviteBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            if (!_paste)
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 300,
                  child: MobileScanner(
                    controller: _scanner,
                    onDetect: (capture) {
                      final raw = capture.barcodes.firstOrNull?.rawValue;
                      if (raw != null && _invite == null) _accept(raw);
                    },
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(l.cameraUnavailable, textAlign: TextAlign.center),
                      ),
                    ),
                  ),
                ),
              )
            else
              TextField(
                controller: _code,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l.inviteCodeLabel),
                onSubmitted: _accept,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(_paste ? Icons.qr_code_scanner : Icons.content_paste),
                label: Text(_paste ? l.scanInviteTitle : l.pasteInvite),
                onPressed: () => setState(() => _paste = !_paste),
              ),
            ),
            if (_paste)
              FilledButton(onPressed: () => _accept(_code.text), child: Text(l.continueAction)),
          ] else ...[
            Card(
              child: ListTile(
                leading: Icon(invite.isReturning ? Icons.waving_hand_outlined : Icons.home_outlined),
                title: Text(invite.isReturning
                    ? l.welcomeBack(invite.memberName ?? '', invite.familyName)
                    : l.joiningFamily(invite.familyName)),
                subtitle: invite.isReturning ? Text(l.welcomeBackBody) : null,
              ),
            ),
            const SizedBox(height: 16),
            if (!invite.isReturning)
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: l.yourNameLabel, hintText: l.yourNameHint),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _join(),
              ),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: (invite.isReturning || _name.text.trim().isNotEmpty) && !_busy ? _join : null,
              child: Text(l.joinAction),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
