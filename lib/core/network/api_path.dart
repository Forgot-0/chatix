/// Ensures API paths match backend conventions (api-docs §0.1, §1.1).
///
/// All versioned endpoints must end with `/`. Query strings are preserved.
/// Exceptions without trailing slash: `/health` (and paths already marked
/// with [skipTrailingSlash] in request extras).
String buildPath(String path) {
  if (path.isEmpty) {
    return '/';
  }

  final queryIndex = path.indexOf('?');
  final hasQuery = queryIndex != -1;
  var pathPart = hasQuery ? path.substring(0, queryIndex) : path;
  final queryPart = hasQuery ? path.substring(queryIndex) : '';

  if (!pathPart.startsWith('/')) {
    pathPart = '/$pathPart';
  }

  // Health check is the only documented path without a trailing slash.
  if (pathPart == '/health') {
    return '$pathPart$queryPart';
  }

  if (!pathPart.endsWith('/')) {
    pathPart = '$pathPart/';
  }

  return '$pathPart$queryPart';
}
