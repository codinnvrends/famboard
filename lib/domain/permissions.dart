import 'models.dart';

/// What a member's role allows (spec section 2).
class Perms {
  const Perms(this.role, this.memberId);

  final Role role;
  final String memberId;

  bool get isAdmin => role == Role.admin;
  /// Admins and adult members can invite, so a family isn't locked out if
  /// its only admin loses their phone.
  bool get canInvite => role == Role.admin || role == Role.member;

  /// Roles this person may give someone new. Only admins create admins.
  List<Role> get invitableRoles => role == Role.admin
      ? const [Role.member, Role.child, Role.viewer, Role.admin]
      : const [Role.member, Role.child, Role.viewer];

  /// Removed members can only be invited back by an admin.
  bool canInviteBack(Member m) => !m.removed || role == Role.admin;
  bool get canManageMembers => role == Role.admin;
  bool get canSeeAmounts => role == Role.admin || role == Role.member;
  bool get canAddEntries => role != Role.viewer;
  bool get canRenameFamily => role == Role.admin;
  bool get canEditCategories => role == Role.admin;

  bool canEdit(Entry e) =>
      role == Role.admin ||
      role == Role.member ||
      (role == Role.child && e.createdBy == memberId);

  bool canDelete(Entry e) =>
      role == Role.admin ||
      role == Role.member ||
      (role == Role.child && e.createdBy == memberId);

  /// Viewers (e.g. a helper) may tick off shopping items; children may close
  /// their own entries and tasks assigned to them.
  bool canComplete(Entry e) => switch (role) {
        Role.admin || Role.member => true,
        Role.viewer => e.type.isShopping,
        Role.child => e.createdBy == memberId || e.assigneeId == memberId,
      };

  bool canClaim(Entry e) => role != Role.viewer || e.type.isShopping;
}
