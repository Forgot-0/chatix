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

  if (pathPart == '/health') {
    return '$pathPart$queryPart';
  }

  if (!pathPart.endsWith('/')) {
    pathPart = '$pathPart/';
  }

  return '$pathPart$queryPart';
}
