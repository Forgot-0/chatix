/// Picking a URL out of `ProfileDTO.avatars` (api-docs §4.3).
///
/// The backend does not hand out one avatar URL: it publishes a matrix of
/// 4 sizes × 3 formats, `{"32"|"64"|"256"|"512": {"jpg"|"webp"|"avif": url}}`,
/// and an empty object `{}` when the user has never uploaded one. Every
/// caller that shows an avatar has to make the same two decisions — which
/// size, which format — so the rule lives here once.
library;

/// The sizes the backend generates, ascending.
const List<int> kAvatarVariantSizes = <int>[32, 64, 256, 512];

/// Formats in the order we prefer them: webp is the smallest of the three
/// that every target platform decodes, avif last because Flutter's decoder
/// support for it is the least even.
const List<String> kAvatarFormatPriority = <String>['webp', 'jpg', 'avif'];

/// The best URL in [avatars] for something being drawn at [preferredSize]
/// physical pixels, or null when the map holds nothing usable.
///
/// Prefers the smallest variant that is still at least [preferredSize] — an
/// avatar scaled down looks right, one scaled up does not — and only falls
/// back to smaller variants when there is nothing larger.
String? pickAvatarUrl(
  Map<String, Map<String, String>> avatars, {
  required int preferredSize,
}) {
  if (avatars.isEmpty) return null;

  final sizes = avatars.keys.map(int.tryParse).whereType<int>().toList()
    ..sort();
  if (sizes.isEmpty) return null;

  final ordered = <int>[
    ...sizes.where((size) => size >= preferredSize),
    ...sizes.where((size) => size < preferredSize).toList().reversed,
  ];

  for (final size in ordered) {
    final formats = avatars['$size'];
    if (formats == null || formats.isEmpty) continue;

    for (final format in kAvatarFormatPriority) {
      final url = formats[format];
      if (url != null && url.isNotEmpty) return url;
    }

    for (final url in formats.values) {
      if (url.isNotEmpty) return url;
    }
  }

  return null;
}
