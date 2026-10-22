import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/utils/link_origin.dart';

/// The public link to somebody's profile: `https://<host>/u/<username>`,
/// the way Telegram hands out `t.me/name`.
///
/// It resolves through `GET /profiles/u/{username}/`, which is public
/// (api-docs §4.3): the app opens it at [UsernameProfileRoute], a ChatiX web
/// build served on the origin does the same, and a handle nobody has any
/// more says so instead of opening a stranger. Built on the host this build
/// talks to, so a staging build hands out staging links.
abstract final class ProfileShareLink {
  /// The link to [username] (without its `@`).
  static String of(String username, {String? baseUrl}) {
    final origin = linkOrigin(baseUrl ?? AppConstants.serverBaseUrl);
    return '$origin${UsernameProfileRoute.locationOf(username)}';
  }

  /// What actually gets shared: the link, introduced by whoever it points at
  /// when that is known.
  static String messageFor({
    required String username,
    String? displayName,
    String? baseUrl,
  }) {
    final link = of(username, baseUrl: baseUrl);

    final name = displayName?.trim();
    final handle = username.trim();

    final who = <String>[
      if (name != null && name.isNotEmpty) name,
      if (handle.isNotEmpty) '@$handle',
    ].join(' ');

    return who.isEmpty ? link : '$who\n$link';
  }

  /// Where in the app [uri] leads, when it is a profile link on this
  /// build's own host — so tapping one in a message opens the profile here
  /// rather than in a browser. Null for anything else.
  ///
  /// Also takes the `/profiles/<id>` links handed out before profiles had a
  /// public address.
  static String? inAppLocation(Uri uri, {String? baseUrl}) {
    final origin = Uri.tryParse(
      linkOrigin(baseUrl ?? AppConstants.serverBaseUrl),
    );
    if (origin == null || !origin.hasAuthority) return null;
    if (!uri.hasAuthority ||
        uri.host.toLowerCase() != origin.host.toLowerCase() ||
        _portOf(uri) != _portOf(origin)) {
      return null;
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length != 2) return null;

    final [kind, value] = segments;
    switch (kind) {
      case 'u':
        final handle = value.trim();
        return handle.isEmpty ? null : UsernameProfileRoute.locationOf(handle);
      case 'profiles':
        final id = int.tryParse(value);
        return id == null || id <= 0 ? null : ProfileDetailRoute(id).location;
    }
    return null;
  }

  static int _portOf(Uri uri) => uri.hasPort
      ? uri.port
      : switch (uri.scheme) {
          'http' => 80,
          _ => 443,
        };
}
