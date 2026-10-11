import 'package:equatable/equatable.dart';

/// How a contact got into the book — `UserContactDTO.source` (api-docs §4.7).
enum ContactSource {
  /// Matched by `POST /contacts/import/`.
  imported(1),

  /// Added by `@username`.
  username(2),

  /// Came in through an invite.
  invite(3),

  /// Added by user id, from a profile.
  manual(4),

  /// A value this build does not know yet.
  unknown(0);

  const ContactSource(this.wire);

  final int wire;

  static ContactSource fromWire(Object? value) {
    for (final source in values) {
      if (source.wire == value) return source;
    }
    return ContactSource.unknown;
  }
}

/// The slice of a profile the contact endpoints attach — `ContactProfileDTO`
/// (api-docs §4.7). Smaller than `ProfileDTO`: no bio, no skills.
class ContactProfile extends Equatable {
  const ContactProfile({
    required this.id,
    this.username,
    this.displayName,
    this.avatars = const <String, Map<String, String>>{},
  });

  /// The user id, named as in `ProfileDTO`.
  final int id;

  /// Without the `@`. Nullable here, unlike in `ProfileDTO`.
  final String? username;

  final String? displayName;

  /// `{ "32"|"64"|"256"|"512": { "jpg"|"webp"|"avif": url } }`, `{}` when unset.
  final Map<String, Map<String, String>> avatars;

  bool get hasAvatar => avatars.isNotEmpty;

  /// The handle with its `@`, or null when there is none.
  String? get handle {
    final value = username?.trim();
    return value == null || value.isEmpty ? null : '@$value';
  }

  /// The display name, or the handle when there is no name.
  String? get bestName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return handle;
  }

  @override
  List<Object?> get props => [id, username, displayName, avatars];
}

/// One row of the caller's address book — `UserContactDTO` (api-docs §4.7).
class Contact extends Equatable {
  const Contact({
    required this.ownerId,
    required this.userId,
    this.firstName,
    this.lastName,
    this.source = ContactSource.unknown,
    this.isMutual = false,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.profile,
  });

  /// Longest `first_name` / `last_name` the server keeps (api-docs §4.7).
  static const int maxNameLength = 64;

  final int ownerId;

  /// `contact_id`: the contact's user id, which is also their profile id.
  final int userId;

  /// The local name: seen only by the owner, never by the contact.
  final String? firstName;
  final String? lastName;

  final ContactSource source;

  /// The contact has added the owner back.
  final bool isMutual;

  final bool isFavorite;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Null while the contact has no profile.
  final ContactProfile? profile;

  /// "First Last" as the owner wrote it, or null when they wrote nothing —
  /// in which case the person's own name is what shows.
  String? get localName {
    final parts = [
      for (final part in [firstName, lastName])
        if (part != null && part.trim().isNotEmpty) part.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  String? get username {
    final value = profile?.username?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// What to call this person: the local name first, as in Telegram, then
  /// their display name, then their handle. Null only for a contact with no
  /// profile and no local name — the screen names that one itself.
  String? get bestName => localName ?? profile?.bestName;

  Contact copyWith({
    String? Function()? firstName,
    String? Function()? lastName,
    bool? isFavorite,
    bool? isMutual,
    DateTime? updatedAt,
    ContactProfile? Function()? profile,
  }) {
    return Contact(
      ownerId: ownerId,
      userId: userId,
      firstName: firstName == null ? this.firstName : firstName(),
      lastName: lastName == null ? this.lastName : lastName(),
      source: source,
      isMutual: isMutual ?? this.isMutual,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile == null ? this.profile : profile(),
    );
  }

  @override
  List<Object?> get props => [
    ownerId,
    userId,
    firstName,
    lastName,
    source,
    isMutual,
    isFavorite,
    createdAt,
    updatedAt,
    profile,
  ];
}
