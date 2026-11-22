import 'models.dart';
import 'warranty.dart';

/// What a member's role allows (spec section 2).
class Perms {
  const Perms(this.role, this.memberId, {bool? seesMoney}) : _seesMoney = seesMoney;

  /// From this device's member record.
  factory Perms.of(Member m) => Perms(m.role, m.id, seesMoney: m.seesMoney);

  final Role role;
  final String memberId;
  final bool? _seesMoney;

  /// How long whoever added a warranty may still fix it themselves.
  static const ownEditWindow = Duration(hours: 24);

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

  /// Bills, expenses and money amounts. Admins always; others when an admin
  /// allowed it (members by default).
  bool get canSeeMoney => role == Role.admin || (_seesMoney ?? role == Role.member);
  bool get canSeeAmounts => canSeeMoney;
  bool get canSeeBills => canSeeMoney;

  /// Whether [e] shows up for this person at all (bills need money access).
  bool canView(Entry e) => e.type != EntryType.bill || canSeeBills;
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

  // Warranties: everyone sees them, admins and members add them, and once
  // saved only admins change them, apart from the adder's first 24 hours.

  bool get canAddAppliance => role == Role.admin || role == Role.member;

  bool _ownAndFresh(String? createdBy, DateTime? createdAt, DateTime now) =>
      createdBy != null &&
      createdBy == memberId &&
      role != Role.viewer &&
      createdAt != null &&
      now.difference(createdAt) < ownEditWindow;

  bool canEditAppliance(Appliance a, {DateTime? now}) =>
      isAdmin || _ownAndFresh(a.createdBy, a.createdAt, now ?? DateTime.now());

  bool canDeleteAppliance(Appliance a, {DateTime? now}) => canEditAppliance(a, now: now);

  /// When the adder's own edit window closes (null if it doesn't apply).
  DateTime? ownEditUntil(Appliance a, {DateTime? now}) {
    if (isAdmin || !_ownAndFresh(a.createdBy, a.createdAt, now ?? DateTime.now())) return null;
    return a.createdAt!.add(ownEditWindow);
  }

  bool get canAddServiceVisit => canAddAppliance;

  bool canEditServiceVisit(ServiceVisit v, {DateTime? now}) =>
      isAdmin || _ownAndFresh(v.createdBy, v.createdAt, now ?? DateTime.now());
}
