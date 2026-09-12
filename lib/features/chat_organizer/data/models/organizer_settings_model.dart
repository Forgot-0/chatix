import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';

part 'organizer_settings_model.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class OrganizerSettingsModel extends Equatable {
  const OrganizerSettingsModel({
    this.unarchiveOnNewMessage = true,
    this.foldersHidden = false,
  });

  factory OrganizerSettingsModel.fromJson(Map<String, dynamic> json) =>
      _$OrganizerSettingsModelFromJson(json);

  factory OrganizerSettingsModel.fromEntity(OrganizerSettings settings) =>
      OrganizerSettingsModel(
        unarchiveOnNewMessage: settings.unarchiveOnNewMessage,
        foldersHidden: settings.foldersHidden,
      );

  @JsonKey(defaultValue: true)
  final bool unarchiveOnNewMessage;

  @JsonKey(defaultValue: false)
  final bool foldersHidden;

  OrganizerSettings toEntity() => OrganizerSettings(
    unarchiveOnNewMessage: unarchiveOnNewMessage,
    foldersHidden: foldersHidden,
  );

  Map<String, dynamic> toJson() => _$OrganizerSettingsModelToJson(this);

  @override
  List<Object?> get props => [unarchiveOnNewMessage, foldersHidden];
}
