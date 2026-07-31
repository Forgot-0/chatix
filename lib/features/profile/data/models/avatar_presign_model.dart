import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';

part 'avatar_presign_model.g.dart';

/// `AvatarPresignResponse` (api-docs §4.5, step 1): `{ url, fields,
/// key_base }`.
@JsonSerializable(fieldRename: FieldRename.snake)
class AvatarPresignModel extends Equatable {
  final String url;
  final Map<String, String> fields;
  final String keyBase;

  const AvatarPresignModel({required this.url, required this.fields, required this.keyBase});

  @override
  List<Object?> get props => [url, fields, keyBase];

  factory AvatarPresignModel.fromJson(Map<String, dynamic> json) =>
      _$AvatarPresignModelFromJson(json);

  Map<String, dynamic> toJson() => _$AvatarPresignModelToJson(this);
}

extension AvatarPresignModelX on AvatarPresignModel {
  AvatarPresignEntity toEntity() {
    return AvatarPresignEntity(url: url, fields: fields, keyBase: keyBase);
  }
}
