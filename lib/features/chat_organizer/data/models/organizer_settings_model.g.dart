// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'organizer_settings_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrganizerSettingsModel _$OrganizerSettingsModelFromJson(
  Map<String, dynamic> json,
) => OrganizerSettingsModel(
  unarchiveOnNewMessage: json['unarchive_on_new_message'] as bool? ?? true,
  foldersHidden: json['folders_hidden'] as bool? ?? false,
);

Map<String, dynamic> _$OrganizerSettingsModelToJson(
  OrganizerSettingsModel instance,
) => <String, dynamic>{
  'unarchive_on_new_message': instance.unarchiveOnNewMessage,
  'folders_hidden': instance.foldersHidden,
};
