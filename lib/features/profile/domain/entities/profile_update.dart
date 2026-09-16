import 'package:equatable/equatable.dart';

import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

/// The whole editable half of a profile, as one value.
///
/// A value object rather than a bag of optional named arguments because
/// `PUT /profiles/{id}/` is not a patch: the handler assigns whatever the
/// body carries straight onto the row, `null` included, so a request that
/// mentions only `bio` wipes the display name, the specialization, the
/// skills and the birthday (api-docs §4.4). Optional parameters cannot tell
/// "leave alone" from "set to null" in Dart either, so the client never
/// tries — every update carries the complete, current set of values, and
/// this type is what makes that impossible to forget.
class ProfileUpdate extends Equatable {
  const ProfileUpdate({
    this.specialization,
    this.displayName,
    this.bio,
    this.skills = const [],
    this.dateBirthday,
  });

  /// The values a profile currently holds, ready to be edited and sent back.
  factory ProfileUpdate.of(ProfileEntity profile) {
    return ProfileUpdate(
      specialization: profile.specialization,
      displayName: profile.displayName,
      bio: profile.bio,
      skills: profile.skills,
      dateBirthday: profile.dateBirthday,
    );
  }

  final String? specialization;
  final String? displayName;
  final String? bio;
  final List<String> skills;
  final DateTime? dateBirthday;

  ProfileUpdate copyWith({
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    DateTime? dateBirthday,
  }) {
    return ProfileUpdate(
      specialization: specialization ?? this.specialization,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      skills: skills ?? this.skills,
      dateBirthday: dateBirthday ?? this.dateBirthday,
    );
  }

  @override
  List<Object?> get props => [
    specialization,
    displayName,
    bio,
    skills,
    dateBirthday,
  ];
}
