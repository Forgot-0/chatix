import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';

part 'chat_profile_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class ChatProfileModel extends Equatable {
  final int userId;
  final String? username;
  final String? displayName;
  final String? avatarUrl;
  final String? avatarS3Key;

  const ChatProfileModel({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.avatarS3Key,
  });

  @override
  List<Object?> get props => [
    userId,
    username,
    displayName,
    avatarUrl,
    avatarS3Key,
  ];

  factory ChatProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ChatProfileModelFromJson(json);

  Map<String, dynamic> toJson() => _$ChatProfileModelToJson(this);
}

extension ChatProfileModelX on ChatProfileModel {
  ChatProfileEntity toEntity() {
    return ChatProfileEntity(
      userId: userId,
      username: username,
      displayName: displayName,
      avatarUrl: avatarUrl,
      avatarS3Key: avatarS3Key,
    );
  }
}
