import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// The mark in front of a chat's name that says what kind of chat it is.
///
/// Drawn rather than picked from an icon font: the four chat types are ours,
/// not Material's, and the set has to read as one family at 14 px — two rings
/// for a group, three for a supergroup, a broadcast cone for a channel. A
/// direct chat gets nothing, because a person's face is already the mark.
class ChatTypeGlyph extends StatelessWidget {
  const ChatTypeGlyph({
    super.key,
    required this.type,
    this.size = 14,
    this.color,
    this.semanticLabel,
  });

  final ChatType type;

  /// Side of the square the glyph is drawn in.
  final double size;

  /// Defaults to the muted foreground, the weight a qualifier wants.
  final Color? color;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (type == ChatType.direct) return const SizedBox.shrink();

    final tint = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Semantics(
      label: semanticLabel,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ChatTypeGlyphPainter(type, tint)),
      ),
    );
  }
}

class _ChatTypeGlyphPainter extends CustomPainter {
  const _ChatTypeGlyphPainter(this.type, this.color);

  /// The box the geometry below is written in; everything scales from it.
  static const double _design = 14;

  final ChatType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _design;
    canvas.save();
    canvas.scale(scale);

    switch (type) {
      case ChatType.direct:
        break;
      case ChatType.group:
        _people(canvas, const [4.5, 9.5], 1);
      case ChatType.supergroup:
        _people(canvas, const [3.4, 7, 10.6], 0.78);
      case ChatType.channel:
        _broadcast(canvas);
    }

    canvas.restore();
  }

  /// A head and a pair of shoulders per person, so the glyph can be counted:
  /// two of them is a group, three is a supergroup.
  void _people(Canvas canvas, List<double> centresX, double scale) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final head = 2.1 * scale;
    final shoulderWidth = 5.6 * scale;
    final shoulderTop = 7.6;
    final shoulderHeight = 3.4 * scale;

    for (final x in centresX) {
      canvas.drawCircle(Offset(x, 5.1), head, fill);

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            x - shoulderWidth / 2,
            shoulderTop,
            shoulderWidth,
            shoulderHeight,
          ),
          topLeft: Radius.circular(shoulderWidth / 2),
          topRight: Radius.circular(shoulderWidth / 2),
          bottomLeft: const Radius.circular(0.8),
          bottomRight: const Radius.circular(0.8),
        ),
        fill,
      );
    }
  }

  /// A cone with two waves coming off it: one voice going out to everybody.
  void _broadcast(Canvas canvas) {
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final cone = Path()
      ..moveTo(1.6, 4.4)
      ..lineTo(6.4, 2.2)
      ..lineTo(6.4, 11.8)
      ..lineTo(1.6, 9.6)
      ..close();
    canvas.drawPath(cone, fill);

    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = color;

    for (final radius in const [3.0, 5.6]) {
      canvas.drawArc(
        Rect.fromCircle(center: const Offset(6.4, 7), radius: radius),
        -math.pi / 3.4,
        math.pi / 1.7,
        false,
        wave,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatTypeGlyphPainter oldDelegate) =>
      oldDelegate.type != type || oldDelegate.color != color;
}
