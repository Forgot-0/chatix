import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// What an empty screen is empty *of*.
///
/// One per situation the app can actually be in, rather than one per screen:
/// two lists that are both empty of people get the same drawing, and that
/// repetition is the point — the picture is a signpost, not decoration.
enum AppIllustrationKind {
  /// No conversations yet.
  conversations,

  /// A conversation with nothing in it.
  messages,

  /// A search that found nothing, or has not been given anything to find.
  search,

  /// No members, no contacts, nobody to show.
  people,

  /// Nothing has happened: an empty notification inbox.
  notifications,

  /// Locked: the screen exists, this account may not see it.
  locked,

  /// No photos, videos or files have been shared here.
  media,
}

/// The empty-state pictures, drawn rather than shipped.
///
/// Every one of them is a few dozen lines of [CustomPainter] over the theme's
/// own colours, which buys three things a bundled asset does not. They
/// re-tint with the accent the moment it changes — a person on a green accent
/// gets green drawings, with no second set of files. They are correct in both
/// themes by construction, because the only colours they know are
/// `colorScheme` roles. And they cost nothing to download and nothing to
/// decode.
///
/// (`flutter_svg` is deliberately not a dependency. Nothing here needs a
/// document format: these are seven shapes, and a vector file would be a
/// parser, a cache and a second styling system to keep in step with the
/// theme.)
class AppIllustration extends StatelessWidget {
  const AppIllustration({
    super.key,
    required this.kind,
    this.size = defaultSize,
  });

  final AppIllustrationKind kind;

  final double size;

  /// Big enough to read as a picture, small enough to leave the words the
  /// most important thing on the screen.
  static const double defaultSize = 108;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _IllustrationPainter(
            kind: kind,
            accent: scheme.primary,
            // The wash the shapes sit on. Low alpha rather than a fixed
            // tint, so it works over either theme's ground.
            wash: scheme.primary.withValues(alpha: 0.12),
            line: scheme.outline,
            faint: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

/// One painter, one switch, because the seven drawings share a vocabulary:
/// the same stroke width, the same rounded joints, the same two fills.
class _IllustrationPainter extends CustomPainter {
  const _IllustrationPainter({
    required this.kind,
    required this.accent,
    required this.wash,
    required this.line,
    required this.faint,
  });

  final AppIllustrationKind kind;
  final Color accent;
  final Color wash;
  final Color line;
  final Color faint;

  /// Every drawing is authored on a 100 × 100 grid and scaled from there, so
  /// the code reads as coordinates rather than as arithmetic.
  static const double _grid = 100;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _grid;
    canvas
      ..save()
      ..scale(scale);

    switch (kind) {
      case AppIllustrationKind.conversations:
        _conversations(canvas);
      case AppIllustrationKind.messages:
        _messages(canvas);
      case AppIllustrationKind.search:
        _search(canvas);
      case AppIllustrationKind.people:
        _people(canvas);
      case AppIllustrationKind.notifications:
        _notifications(canvas);
      case AppIllustrationKind.locked:
        _locked(canvas);
      case AppIllustrationKind.media:
        _media(canvas);
    }

    canvas.restore();
  }

  // ── the shared vocabulary ─────────────────────────────────────────────

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = line;

  Paint get _accentStroke => _stroke..color = accent;

  Paint get _fill => Paint()..color = wash;

  Paint get _faintStroke => _stroke
    ..color = faint
    ..strokeWidth = 2.5;

  /// A chat bubble: a rounded rectangle with one corner pulled into a tail,
  /// the same anchor the app's own message bubbles use.
  Path _bubble(Rect rect, {required bool tailLeft}) {
    final body = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(AppRadii.lg),
      topRight: const Radius.circular(AppRadii.lg),
      bottomLeft: Radius.circular(tailLeft ? 2 : AppRadii.lg),
      bottomRight: Radius.circular(tailLeft ? AppRadii.lg : 2),
    );
    return Path()..addRRect(body);
  }

  void _line(Canvas canvas, Offset start, double length, {Paint? paint}) {
    canvas.drawLine(start, start + Offset(length, 0), paint ?? _faintStroke);
  }

  // ── the drawings ──────────────────────────────────────────────────────

  /// Two bubbles, one behind the other: a conversation list with nothing in
  /// it yet.
  void _conversations(Canvas canvas) {
    final back = _bubble(const Rect.fromLTWH(30, 14, 58, 40), tailLeft: false);
    canvas
      ..drawPath(back, _fill)
      ..drawPath(back, _faintStroke);

    final front = _bubble(const Rect.fromLTWH(12, 44, 62, 42), tailLeft: true);
    canvas
      ..drawPath(front, _fill)
      ..drawPath(front, _accentStroke);

    _line(canvas, const Offset(24, 60), 32);
    _line(canvas, const Offset(24, 71), 20);
  }

  /// One bubble and the three dots that have not been typed yet.
  void _messages(Canvas canvas) {
    final bubble = _bubble(const Rect.fromLTWH(14, 24, 72, 46), tailLeft: true);
    canvas
      ..drawPath(bubble, _fill)
      ..drawPath(bubble, _accentStroke);

    final dot = Paint()..color = accent;
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(34.0 + i * 16, 47), 4, dot);
    }
  }

  /// A lens over a list: looking, rather than found.
  void _search(Canvas canvas) {
    _line(canvas, const Offset(16, 24), 40);
    _line(canvas, const Offset(16, 38), 26);

    const centre = Offset(58, 54);
    canvas
      ..drawCircle(centre, 24, _fill)
      ..drawCircle(centre, 24, _accentStroke)
      ..drawLine(
        centre + const Offset(17, 17),
        centre + const Offset(30, 30),
        _accentStroke,
      );
  }

  /// Three faces, the nearest one in accent: a roster with nobody in it.
  void _people(Canvas canvas) {
    void figure(Offset centre, double radius, Paint paint) {
      canvas
        ..drawCircle(centre, radius, _fill)
        ..drawCircle(centre, radius, paint);

      // Shoulders: an arc under the head, open at the bottom.
      final shoulders = Rect.fromCircle(
        center: centre + Offset(0, radius * 2.4),
        radius: radius * 1.7,
      );
      canvas.drawArc(shoulders, math.pi, math.pi, false, paint);
    }

    // The two behind sit lower and smaller, so the one in front reads as
    // nearer rather than as merely larger.
    figure(const Offset(22, 40), 10, _faintStroke);
    figure(const Offset(78, 40), 10, _faintStroke);
    figure(const Offset(50, 30), 15, _accentStroke);
  }

  /// A bell with nothing to ring about.
  void _notifications(Canvas canvas) {
    final body = Path()
      ..moveTo(26, 62)
      ..lineTo(26, 46)
      // Two arcs rather than one: the dome is wider than it is tall, and a
      // circle here reads as a balloon.
      ..arcToPoint(const Offset(74, 46), radius: const Radius.circular(26))
      ..lineTo(74, 62)
      ..lineTo(80, 70)
      ..lineTo(20, 70)
      ..close();

    canvas
      ..drawPath(body, _fill)
      ..drawPath(body, _accentStroke)
      // The clapper.
      ..drawArc(
        const Rect.fromLTWH(42, 70, 16, 14),
        0,
        math.pi,
        false,
        _accentStroke,
      );
  }

  /// A closed padlock: there is something here, and it is not yours.
  void _locked(Canvas canvas) {
    final shackle = Rect.fromCircle(center: const Offset(50, 42), radius: 16);
    canvas.drawArc(shackle, math.pi, math.pi, false, _faintStroke);

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(26, 42, 48, 38),
      const Radius.circular(AppRadii.md),
    );
    canvas
      ..drawRRect(body, _fill)
      ..drawRRect(body, _accentStroke)
      ..drawCircle(const Offset(50, 59), 4, Paint()..color = accent)
      ..drawLine(const Offset(50, 61), const Offset(50, 68), _accentStroke);
  }

  /// A frame with a horizon in it: the shape of a photo, without a photo.
  void _media(Canvas canvas) {
    final frame = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 22, 68, 56),
      const Radius.circular(AppRadii.lg),
    );
    canvas
      ..drawRRect(frame, _fill)
      ..drawRRect(frame, _accentStroke)
      ..drawCircle(const Offset(36, 40), 6, _faintStroke)
      // The hills, clipped to the frame so they cannot escape it.
      ..save()
      ..clipRRect(frame);

    final hills = Path()
      ..moveTo(20, 74)
      ..lineTo(42, 52)
      ..lineTo(56, 66)
      ..lineTo(66, 56)
      ..lineTo(84, 74)
      ..close();

    canvas
      ..drawPath(hills, _faintStroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_IllustrationPainter old) =>
      old.kind != kind ||
      old.accent != accent ||
      old.wash != wash ||
      old.line != line ||
      old.faint != faint;
}
