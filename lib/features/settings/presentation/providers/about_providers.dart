import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The installed build: the version people quote and the build number
/// support asks for next.
class AppVersion {
  const AppVersion({required this.version, required this.build});

  final String version;
  final String build;
}

/// What the platform says is installed — the store's version, not a
/// constant somebody forgets to bump.
final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion(version: info.version, build: info.buildNumber);
});

/// The pages About links to, each behind its own key in `.env`.
///
/// Configured rather than written down here: the addresses belong to
/// whoever runs the deployment, and a row that opens somebody else's
/// placeholder domain is worse than no row. An unset or malformed key
/// leaves its row out.
enum AboutLink {
  privacyPolicy('PRIVACY_POLICY_URL'),
  terms('TERMS_URL'),
  support('SUPPORT_URL');

  const AboutLink(this.envKey);

  final String envKey;
}

/// The links this build was configured with, in [AboutLink] order. Only
/// `https` addresses count — About opens them in the browser, and a link
/// that downgrades to http is not one to put under a privacy policy.
final aboutLinksProvider = Provider<Map<AboutLink, Uri>>((ref) {
  // A test, or a build started without `.env`, has nothing to read.
  if (!dotenv.isInitialized) return const {};

  return {
    for (final link in AboutLink.values)
      link: ?_https(dotenv.maybeGet(link.envKey)),
  };
});

Uri? _https(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
