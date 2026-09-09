import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/profile/data/models/contact_model.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

part 'profile_model.g.dart';

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

  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

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
