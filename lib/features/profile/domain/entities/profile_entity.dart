import 'package:equatable/equatable.dart';

import 'package:chatix/core/media/avatar_variants.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';

class ProfileEntity extends Equatable {
  final int id;

  /// The `@handle`, without the `@` and never null — the one identifier a
  /// person always has, since `displayName` is optional and not unique
  /// (api-docs §4.3).
  final String username;

  final Map<String, Map<String, String>> avatars;
  final String? specialization;
  final String? displayName;
  final String? bio;

  final DateTime? dateBirthday;

  final List<String> skills;
  final List<ContactEntity> contacts;

  const ProfileEntity({
    required this.id,
    required this.username,
    required this.avatars,
    required this.specialization,
    required this.displayName,
    required this.bio,
    required this.dateBirthday,
    required this.skills,
    required this.contacts,
  });

  bool get hasAvatar => avatars.isNotEmpty;

  /// The avatar to draw at [preferredSize] physical pixels, or null when the
  /// user has none. The size/format rule is shared with every other avatar
  /// surface — see `pickAvatarUrl` (api-docs §4.3).
  String? bestAvatarUrl(int preferredSize) =>
      pickAvatarUrl(avatars, preferredSize: preferredSize);

  ProfileEntity copyWith({
    int? id,
    String? username,
    Map<String, Map<String, String>>? avatars,
    String? specialization,
    String? displayName,
    String? bio,
    DateTime? dateBirthday,
    List<String>? skills,
    List<ContactEntity>? contacts,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      avatars: avatars ?? this.avatars,
      specialization: specialization ?? this.specialization,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      dateBirthday: dateBirthday ?? this.dateBirthday,
      skills: skills ?? this.skills,
      contacts: contacts ?? this.contacts,
    );
  }

  @override
  List<Object?> get props => [
    id,
    username,
    avatars,
    specialization,
    displayName,
    bio,
    dateBirthday,
    skills,
    contacts,
  ];
}
