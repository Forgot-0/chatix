import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';

part 'call_token_model.g.dart';

/// `JoinTokenDTO` (api-docs §6.6) — LiveKit access token for the chat's call.
@JsonSerializable(fieldRename: FieldRename.snake)
class CallTokenModel extends Equatable {
  final String token;
  final String slug;
  final String livekitUrl;

  const CallTokenModel({
    required this.token,
    required this.slug,
    required this.livekitUrl,
  });

  @override
  List<Object?> get props => [token, slug, livekitUrl];

  factory CallTokenModel.fromJson(Map<String, dynamic> json) =>
      _$CallTokenModelFromJson(json);

  Map<String, dynamic> toJson() => _$CallTokenModelToJson(this);
}

extension CallTokenModelX on CallTokenModel {
  CallTokenEntity toEntity() =>
      CallTokenEntity(token: token, slug: slug, livekitUrl: livekitUrl);
}
