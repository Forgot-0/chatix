import 'package:chatix/features/profile/domain/entities/profile_photo.dart';

/// `ProfilePhotoDTO` off the wire (api-docs §4.5.1).
///
/// Read by hand rather than generated: four fields, one of them the same
/// nested map `ProfileDTO.avatars` is, and a shape mismatch here should
/// cost one picture, not the whole page.
abstract final class ProfilePhotoModel {
  static ProfilePhoto fromJson(Map<String, dynamic> json) {
    return ProfilePhoto(
      id: json['id'] as String,
      avatars: avatarsFromJson(json['avatars']),
      isMain: json['is_main'] == true,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  /// `{ "32"|"64"|"256"|"512": { "jpg"|"webp": url } }`, dropping anything
  /// that is not a string at the leaves — `{}` when unset.
  static Map<String, Map<String, String>> avatarsFromJson(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final MapEntry(:key, :value) in raw.entries)
        if (value is Map)
          '$key': {
            for (final MapEntry(key: format, value: url) in value.entries)
              if (url is String) '$format': url,
          },
    };
  }
}
