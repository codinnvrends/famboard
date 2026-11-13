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

/// Shows a 15-minute QR invite for the active family (spec FR-2): for a new
/// person, or for someone already in the family who reinstalled or changed
/// phones.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _returning = false;
  Role _role = Role.member;
  Member? _member;
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
    if (_returning && _member == null) {
      setState(() => _invite = null);
      return;
    }
    final invite = await ref.read(servicesProvider).repo.createInvite(
          familyId: session.familyId,
          familyName: ref.read(familyNameProvider),
          invitedBy: session.memberId,
          role: _role,
          returning: _returning ? _member : null,
        );
    if (mounted) setState(() => _invite = invite);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final perms = ref.watch(permsProvider);
    final members = session == null
        ? const <Member>[]
        : (ref.watch(membersProvider(session.familyId)).value ?? const <Member>[])
            .where((m) => m.id != session.memberId && perms.canInviteBack(m))
            .toList();
    final invite = _invite;
    final remaining = invite?.expiresAt.difference(DateTime.now());
    final expired = remaining != null && remaining.isNegative;

    return Scaffold(
      appBar: AppBar(title: Text(l.inviteTitle(ref.watch(familyNameProvider)))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, icon: const Icon(Icons.person_add_alt), label: Text(l.inviteNewPerson)),
              ButtonSegment(value: true, icon: const Icon(Icons.restore), label: Text(l.inviteReturning)),
            ],
            selected: {_returning},
            onSelectionChanged: (s) {
              setState(() => _returning = s.first);
              _create();
            },
          ),
          const SizedBox(height: 16),
          if (!_returning) ...[
            Text(l.inviteJoinAs, style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            for (final r in perms.invitableRoles)
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
          ] else ...[
            Text(l.inviteReturningBody, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (members.isEmpty)
              Text(l.inviteNoOneToBringBack, style: theme.textTheme.bodySmall)
            else
              for (final m in members)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    selected: _member?.id == m.id,
                    leading: MemberAvatar(m),
                    title: Text(m.name),
                    subtitle: Text(m.removed ? '${m.role.label(l)} · ${l.removedLabel}' : m.role.label(l)),
                    trailing: Icon(_member?.id == m.id ? Icons.radio_button_checked : Icons.radio_button_off),
                    onTap: () {
                      setState(() => _member = m);
                      _create();
                    },
                  ),
                ),
          ],
          const SizedBox(height: 16),
          if (invite == null)
            if (_returning)
              const SizedBox.shrink()
            else
              const Center(child: CircularProgressIndicator())
          else if (expired)
            EmptyState(
              icon: Icons.timer_off_outlined,
              title: l.inviteExpiredTitle,
              action: FilledButton(onPressed: _create, child: Text(l.inviteNewCode)),
            )
          else ...[
            if (invite.isReturning)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.inviteReturningFor(invite.memberName ?? '', invite.role.label(l)),
                  style: theme.textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: QrImageView(data: invite.encode(), size: 260, backgroundColor: Colors.white),
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
