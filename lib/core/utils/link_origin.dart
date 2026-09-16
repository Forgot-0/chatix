/// Turning the configured API base URL into somewhere a person can be sent.
library;

/// `https://host[:port]` from [raw], with whatever path, query or fragment
/// it carries dropped.
///
/// The configured base URL points at the API (`https://host/api/v1`), which
/// is where requests go and not where a link should land. Rebuilt rather
/// than `replace`d, which would leave an empty `?#` behind. A value that is
/// not a URL at all comes back trimmed and unchanged, so a misconfigured
/// build produces something odd rather than nothing.
String linkOrigin(String raw) {
  final trimmed = raw.trim();
  final withoutSlash = trimmed.endsWith('/')
      ? trimmed.substring(0, trimmed.length - 1)
      : trimmed;

  final uri = Uri.tryParse(withoutSlash);
  if (uri == null || !uri.hasAuthority) return withoutSlash;

  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}
