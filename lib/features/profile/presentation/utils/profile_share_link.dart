import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/utils/link_origin.dart';

/// The link that points at somebody's profile.
///
/// ⚠️ Composed here rather than fetched, for the same reason a chat invite
/// is: the API has no shareable identity for a profile. `ProfileDTO` carries
/// no slug, no public URL and not even a `username` (api-docs §4.3), and
/// `GET /profiles/{id}/` needs a token, so nothing minted here opens in a
/// browser for a stranger.
///
/// What the link is good for is passing a person around inside the app — in
/// a message, in an email to somebody who already has ChatiX. It is worded
/// that way on screen, and the gap is written down in
/// `docs/BACKEND_GAPS.md`.
abstract final class ProfileShareLink {
  /// `https://<host>/profiles/<id>` — this app's own route, on the host this
  /// build talks to, so a staging build hands out staging links.
  static String of(int profileId, {String? baseUrl}) {
    final origin = linkOrigin(baseUrl ?? AppConstants.serverBaseUrl);
    return '$origin/profiles/$profileId';
  }

  /// What actually gets shared: the link, introduced by whoever it points at
  /// when that is known.
  static String messageFor(
    int profileId, {
    String? displayName,
    String? username,
    String? baseUrl,
  }) {
    final link = of(profileId, baseUrl: baseUrl);

    final name = displayName?.trim();
    final handle = username?.trim();

    final who = <String>[
      if (name != null && name.isNotEmpty) name,
      if (handle != null && handle.isNotEmpty) '@$handle',
    ].join(' ');

    return who.isEmpty ? link : '$who\n$link';
  }
}
