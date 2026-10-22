import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// The providers' own files, copied unchanged from their downloads
/// (2026-10-22):
///
///  * `google_light.png`, `google_dark.png` and their `2.0x`–`4.0x`
///    variants: the icon-only square button from `signin-assets.zip` on
///    developers.google.com/identity/branding-guidelines ("Android + Web",
///    PNG @1x–@4x, Light and Dark).
///  * `github_mark_black.png`, `github_mark_white.png`:
///    `GitHub_Invertocat_Black.png` and `_White.png` from
///    brand.github.com/GitHub_Logos.zip.
///
/// Yandex publishes its icon only as SVG, which this app has no renderer
/// for; [YandexMark] draws it from that SVG's own path data instead.
abstract final class OAuthMarkAssets {
  static const String googleLight = 'assets/brand/oauth/google_light.png';
  static const String googleDark = 'assets/brand/oauth/google_dark.png';
  static const String githubBlack = 'assets/brand/oauth/github_mark_black.png';
  static const String githubWhite = 'assets/brand/oauth/github_mark_white.png';
}

/// Google's "G", shown from Google's own file rather than redrawn.
///
/// The file is Google's whole 40 px icon button — fill, stroke and the "G"
/// in its middle 20 px. Only that middle is shown, so the "G" stands on the
/// button fill Google drew it on, and the button around it supplies the
/// same fill ([OAuthButtonSpec.lightFill] / [OAuthButtonSpec.darkFill]).
/// Google forbids recolouring the mark or using a monochrome one; the dark
/// file is its own answer for dark buttons.
class GoogleMark extends StatelessWidget {
  const GoogleMark({required this.dark, super.key});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    const size = OAuthButtonSpec.googleMark;
    // The file is twice the mark's size: the mark is its middle half.
    const file = size * 2;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: ClipRect(
          child: OverflowBox(
            minWidth: file,
            maxWidth: file,
            minHeight: file,
            maxHeight: file,
            child: Image.asset(
              dark ? OAuthMarkAssets.googleDark : OAuthMarkAssets.googleLight,
              width: file,
              height: file,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

/// GitHub's Invertocat, black on a light button and white on a dark one —
/// the two colours GitHub's brand page allows for it.
class GitHubMark extends StatelessWidget {
  const GitHubMark({required this.dark, super.key});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        dark ? OAuthMarkAssets.githubWhite : OAuthMarkAssets.githubBlack,
        height: OAuthButtonSpec.githubMark,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Yandex ID's round icon: the red disc with the white letter.
///
/// Yandex draws a Cyrillic "Я" for Russian and a Latin "Y" for every other
/// language, in both its icon files and its buttons, so [cyrillic] follows
/// the reader's language.
class YandexMark extends StatelessWidget {
  const YandexMark({required this.cyrillic, super.key});

  final bool cyrillic;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: OAuthButtonSpec.yandexMark,
        child: CustomPaint(painter: YandexMarkPainter(cyrillic: cyrillic)),
      ),
    );
  }
}

/// Paints [YandexMark] from the path data in Yandex's own icon files — the
/// pill icon button `login-with-yandex-8-2.svg` from the Yandex ID button
/// guidelines, Russian and English editions. The strings below are copied
/// from those files verbatim, on their 44 × 44 grid.
class YandexMarkPainter extends CustomPainter {
  const YandexMarkPainter({required this.cyrillic});

  final bool cyrillic;

  static const double _grid = 44;

  static const String cyrillicGlyph =
      'M25.2438 12.3208H23.0173C19.2005 12.3208 17.292 14.2292 17.292 '
      '17.0919C17.292 20.2726 18.5643 21.863 21.427 23.7714L23.6535 '
      '25.3618L17.292 35.222H12.2029L18.2463 26.316C14.7475 23.7714 12.839 '
      '21.5449 12.839 17.41C12.839 12.3208 16.3378 8.82202 23.0173 '
      '8.82202H29.6969V35.222H25.2438V12.3208Z';

  static const String latinGlyph =
      'M22.5968 24.2728C23.8823 27.0888 24.3109 28.0682 24.3109 '
      '31.4505V35.9347H19.7196V28.3743L11.0573 9.53467H15.8476L22.5968 '
      '24.2728ZM28.2594 9.53467L22.6427 22.2985H27.3105L32.9425 '
      '9.53467H28.2594Z';

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    canvas
      ..save()
      ..scale(scale)
      ..drawCircle(
        const Offset(_grid / 2, _grid / 2),
        _grid / 2,
        Paint()..color = OAuthButtonSpec.yandexRed,
      )
      ..drawPath(
        parseSvgPathData(cyrillic ? cyrillicGlyph : latinGlyph),
        Paint()..color = OAuthButtonSpec.yandexPaper,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(YandexMarkPainter oldDelegate) =>
      cyrillic != oldDelegate.cyrillic;
}

/// Reads SVG path data made of the absolute commands an icon export uses:
/// `M`, `L`, `H`, `V`, `C` and `Z`, a command letter repeating implicitly
/// for further coordinates.
///
/// Enough for the provider icons above, drawn from their owners' files
/// rather than retraced; anything else throws, so a new icon with relative
/// or arc commands fails loudly instead of drawing something close.
Path parseSvgPathData(String data) {
  final tokens = RegExp(
    r'[A-Za-z]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
  ).allMatches(data).map((match) => match.group(0)!).toList();

  final path = Path();
  var index = 0;
  String? command;
  var current = Offset.zero;
  var start = Offset.zero;

  bool isCommand(String token) => RegExp(r'^[A-Za-z]$').hasMatch(token);
  double number() {
    if (index >= tokens.length || isCommand(tokens[index])) {
      throw FormatException('Path data ends in the middle of "$command"');
    }
    return double.parse(tokens[index++]);
  }

  while (index < tokens.length) {
    if (isCommand(tokens[index])) {
      command = tokens[index++];
    } else if (command == null || command == 'Z') {
      throw FormatException('Coordinates with no command: ${tokens[index]}');
    }

    switch (command) {
      case 'M':
        current = start = Offset(number(), number());
        path.moveTo(current.dx, current.dy);
        // Further pairs after a move are lines.
        command = 'L';
      case 'L':
        current = Offset(number(), number());
        path.lineTo(current.dx, current.dy);
      case 'H':
        current = Offset(number(), current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        current = Offset(current.dx, number());
        path.lineTo(current.dx, current.dy);
      case 'C':
        final c1 = Offset(number(), number());
        final c2 = Offset(number(), number());
        current = Offset(number(), number());
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
      case 'Z':
        path.close();
        current = start;
      default:
        throw FormatException('Unsupported path command "$command"');
    }
  }

  return path;
}
