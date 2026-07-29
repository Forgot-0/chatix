import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';

part 'user_model.g.dart';

/// Wire model for `UserResponse` (api-docs §3.2, §3.9): `{id, username, email}`.
/// Flat and already matches Dart naming 1:1, so no `fieldRename` is needed.
@JsonSerializable()
class UserModel extends Equatable {
  final int id;
  final String username;
  final String email;

  const UserModel({required this.id, required this.username, required this.email});

  @override
  List<Object?> get props => [id, username, email];

  factory UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(id: entity.id, username: entity.username, email: entity.email);
  }
}

extension UserModelX on UserModel {
  UserEntity toEntity() {
    return UserEntity(id: id, username: username, email: email);
  }
}
