import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/profile/domain/entities/avatar_presign_entity.dart';

part 'avatar_presign_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class AvatarPresignModel extends Equatable {
  final String url;

  final String fileKey;

  const AvatarPresignModel({required this.url, required this.fileKey});

  @override
  List<Object?> get props => [url, fileKey];

  factory AvatarPresignModel.fromJson(Map<String, dynamic> json) =>
      _$AvatarPresignModelFromJson(json);

  Map<String, dynamic> toJson() => _$AvatarPresignModelToJson(this);
}

extension AvatarPresignModelX on AvatarPresignModel {
  AvatarPresignEntity toEntity() =>
      AvatarPresignEntity(url: url, fileKey: fileKey);
}
