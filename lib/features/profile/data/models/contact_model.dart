import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';

part 'contact_model.g.dart';

/// `ContactDTO` (api-docs §4.3): `{ profile_id, provider, contact }`.
@JsonSerializable(fieldRename: FieldRename.snake)
class ContactModel extends Equatable {
  final int profileId;
  final String provider;
  final String contact;

  const ContactModel({
    required this.profileId,
    required this.provider,
    required this.contact,
  });

  @override
  List<Object?> get props => [profileId, provider, contact];

  factory ContactModel.fromJson(Map<String, dynamic> json) => _$ContactModelFromJson(json);

  Map<String, dynamic> toJson() => _$ContactModelToJson(this);

  factory ContactModel.fromEntity(ContactEntity entity) {
    return ContactModel(
      profileId: entity.profileId,
      provider: entity.provider,
      contact: entity.contact,
    );
  }
}

extension ContactModelX on ContactModel {
  ContactEntity toEntity() {
    return ContactEntity(profileId: profileId, provider: provider, contact: contact);
  }
}
