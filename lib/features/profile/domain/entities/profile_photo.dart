import 'package:equatable/equatable.dart';

import 'package:chatix/core/media/avatar_variants.dart';

/// One picture in a person's photo history — `ProfilePhotoDTO`
/// (api-docs §4.5.1).
///
/// The current one is what `ProfileDTO.avatars` and the chats show; the
/// rest are the pictures the person had before, newest first, up to a
/// hundred of them.
class ProfilePhoto extends Equatable {
  const ProfilePhoto({
    required this.id,
    required this.avatars,
    required this.isMain,
    required this.createdAt,
  });

  /// A UUID. What `PUT /profiles/photos/{id}/main/` and
  /// `DELETE /profiles/photos/{id}/` address.
  final String id;

  /// Presigned for 300 s, like the profile's own (api-docs §0.9).
  final Map<String, Map<String, String>> avatars;

  /// The current photo — the first row of the first page.
  final bool isMain;

  /// When it was uploaded.
  final DateTime createdAt;

  /// The variant to draw at [preferredSize] physical pixels, or null when
  /// the server sent none.
  String? bestUrl(int preferredSize) =>
      pickAvatarUrl(avatars, preferredSize: preferredSize);

  /// The object key behind a presigned [url]: the path without the
  /// signature. Every photo has keys of its own
  /// (`{user_id}/{photo_id}/{size}.{fmt}`), so this is what a picture is
  /// cached by — the URL changes on every read, the key never does
  /// (api-docs §4.3).
  static String cacheKeyOf(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.path.isEmpty) return url;
    return '${uri.host}${uri.path}';
  }

  @override
  List<Object?> get props => [id, avatars, isMain, createdAt];
}
