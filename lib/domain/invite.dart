import 'dart:convert';
import 'dart:typed_data';

import 'models.dart';

/// A family invite carried in a QR code (spec FR-2).
///
/// The QR holds the family key, so it is only shown on screen, in person, and
/// expires after 15 minutes.
class FamilyInvite {
  const FamilyInvite({
    required this.familyId,
    required this.familyName,
    required this.key,
    required this.role,
    required this.invitedBy,
    required this.expiresAt,
    this.memberId,
    this.memberName,
  });

  final String familyId;
  final String familyName;
  final Uint8List key;
  final Role role;
  final String invitedBy;
  final DateTime expiresAt;

  /// Set when inviting back someone already in the family (e.g. after they
  /// reinstalled): the new phone takes over that member, with their name,
  /// role and history, instead of creating a new one.
  final String? memberId;
  final String? memberName;

  bool get isReturning => memberId != null;

  static const scheme = 'famboard://join?d=';
  static const validFor = Duration(minutes: 15);

  bool isExpired([DateTime? now]) => (now ?? DateTime.now()).isAfter(expiresAt);

  String encode() {
    final json = jsonEncode({
      'v': 1,
      'f': familyId,
      'n': familyName,
      'k': base64Url.encode(key),
      'r': role.code,
      'b': invitedBy,
      'x': expiresAt.millisecondsSinceEpoch ~/ 1000,
      if (memberId != null) 'm': memberId,
      if (memberName != null) 'mn': memberName,
    });
    return '$scheme${base64Url.encode(utf8.encode(json))}';
  }

  /// Parses a scanned or pasted invite. Throws [FormatException] if invalid.
  factory FamilyInvite.decode(String raw) {
    final text = raw.trim();
    if (!text.startsWith(scheme)) {
      throw const FormatException('Not a FamBoard invite');
    }
    final payload = text.substring(scheme.length);
    final map = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(payload))))
        as Map<String, Object?>;
    if (map['v'] != 1) throw const FormatException('Unsupported invite version');
    final key = base64Url.decode(map['k']! as String);
    if (key.length != 32) throw const FormatException('Bad family key');
    return FamilyInvite(
      familyId: map['f']! as String,
      familyName: map['n'] as String? ?? '',
      key: Uint8List.fromList(key),
      role: Role.fromCode(map['r']),
      invitedBy: map['b'] as String? ?? '',
      expiresAt: DateTime.fromMillisecondsSinceEpoch(((map['x'] ?? 0) as num).toInt() * 1000),
      memberId: map['m'] as String?,
      memberName: map['mn'] as String?,
    );
  }
}
