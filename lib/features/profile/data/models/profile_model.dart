import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/profile/data/models/contact_model.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

part 'profile_model.g.dart';

/// `ProfileDTO` (api-docs §4.3).
///
/// [dateBirthday] is intentionally kept as the raw `"YYYY-MM-DD"` wire
/// string here rather than a `DateTime` — `DateTime.parse` round-trips
/// through a full ISO-8601 instant, which is more than this field is
/// (api-docs §1.9: `date_birthday` is a plain `date`, not a `datetime`).
/// The date-only ↔ `DateTime` conversion happens once, at the model/entity
/// boundary in [toEntity]/`ProfileRemoteDataSourceImpl`, so the rest of the
/// app only ever deals with the domain `DateTime?`.
@JsonSerializable(fieldRename: FieldRename.snake)
class ProfileModel extends Equatable {
  final int id;
  final Map<String, Map<String, String>> avatars;
  final String? specialization;
  final String? displayName;
  final String? bio;
  final String? dateBirthday;
  final List<String> skills;
  final List<ContactModel> contacts;

  const ProfileModel({
    required this.id,
    required this.avatars,
    required this.specialization,
    required this.displayName,
    required this.bio,
    required this.dateBirthday,
    required this.skills,
    required this.contacts,
  });

  @override
  List<Object?> get props => [
    id,
    avatars,
    specialization,
    displayName,
    bio,
    dateBirthday,
    skills,
    contacts,
  ];

  factory ProfileModel.fromJson(Map<String, dynamic> json) => _$ProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);
}

extension ProfileModelX on ProfileModel {
  ProfileEntity toEntity() {
    return ProfileEntity(
      id: id,
      avatars: avatars,
      specialization: specialization,
      displayName: displayName,
      bio: bio,
      dateBirthday: dateBirthday != null ? DateTime.parse(dateBirthday!) : null,
      skills: skills,
      contacts: contacts.map((contact) => contact.toEntity()).toList(),
    );
  }
}
