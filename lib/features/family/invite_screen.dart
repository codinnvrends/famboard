import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/providers.dart';
import '../../domain/invite.dart';
import '../../domain/models.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

/// Shows a 15-minute QR invite for the active family (spec FR-2).
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  Role _role = Role.member;
  FamilyInvite? _invite;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _create());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final invite = await ref.read(servicesProvider).repo.createInvite(
          familyId: session.familyId,
          familyName: ref.read(familyNameProvider),
          invitedBy: session.memberId,
          role: _role,
        );
    if (mounted) setState(() => _invite = invite);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final invite = _invite;
    final remaining = invite?.expiresAt.difference(DateTime.now());
    final expired = remaining != null && remaining.isNegative;

    return Scaffold(
      appBar: AppBar(title: Text(l.inviteTitle(ref.watch(familyNameProvider)))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(l.inviteJoinAs, style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final r in [Role.member, Role.child, Role.viewer, Role.admin])
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                selected: _role == r,
                leading: Icon(_role == r ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(r.label(l)),
                subtitle: Text(r.description(l)),
                onTap: () {
                  setState(() => _role = r);
                  _create();
                },
              ),
            ),
          const SizedBox(height: 16),
          if (invite == null)
            const Center(child: CircularProgressIndicator())
          else if (expired)
            EmptyState(
              icon: Icons.timer_off_outlined,
              title: l.inviteExpiredTitle,
              action: FilledButton(onPressed: _create, child: Text(l.inviteNewCode)),
            )
          else ...[
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: QrImageView(
                  data: invite.encode(),
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                l.inviteExpiresIn(
                  '${remaining!.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}',
                ),
                style: theme.textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 12),
            Text(l.inviteInstructions, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.copy),
                label: Text(l.inviteCopyCode),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.encode()));
                  if (context.mounted) showSnack(context, l.copied);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
