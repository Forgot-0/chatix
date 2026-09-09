import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// Three dots that rise and fade in turn.
///
/// Nothing drives this today: the backend declares `typing_start` /
/// `typing_stop` but never publishes either (api-docs §6.4), so the widget is
/// here for the day it does. It renders only what it is handed — it will not
/// invent activity of its own.
class TypingDots extends StatefulWidget {
  const TypingDots({
    super.key,
    this.color,
    this.dotSize = 5,
    this.spacing = 3,
    this.period = const Duration(milliseconds: 1200),
  });

  final Color? color;
  final double dotSize;
  final double spacing;

  /// One full pass across the three dots.
  final Duration period;

  static const int dotCount = 3;

  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.period,
  );

  @override
  void initState() {
    super.initState();
    _controller.repeat();
  }

  @override
  void didUpdateWidget(TypingDots oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.period != oldWidget.period) {
      _controller.duration = widget.period;
      if (_controller.isAnimating) _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    final still = MediaQuery.disableAnimationsOf(context);

    if (still) {
      // Reduced motion: the dots stay put and only differ in weight, so the
      // indicator still reads as "someone is writing" without moving.
      return _Row(
        dotSize: widget.dotSize,
        spacing: widget.spacing,
        builder: (index) => _Dot(
          size: widget.dotSize,
          color: color.withValues(alpha: 0.4 + index * 0.2),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _Row(
        dotSize: widget.dotSize,
        spacing: widget.spacing,
        builder: (index) {
          final t = _phase(index);
          return Transform.translate(
            offset: Offset(0, -widget.dotSize * 0.5 * t),
            child: _Dot(
              size: widget.dotSize,
              color: color.withValues(alpha: 0.35 + 0.65 * t),
            ),
          );
        },
      ),
    );
  }

  /// 0 → 1 → 0 for one dot, each starting a third of a cycle after the last.
  double _phase(int index) {
    final offset = index / TypingDots.dotCount;
    final local = (_controller.value - offset) % 1;
    final wave = local < 0.5 ? local * 2 : (1 - local) * 2;
    return Curves.easeOutCubic.transform(wave.clamp(0.0, 1.0));
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.dotSize,
    required this.spacing,
    required this.builder,
  });

  final double dotSize;
  final double spacing;
  final Widget Function(int index) builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dotSize * 2,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < TypingDots.dotCount; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            builder(i),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// The dots with a caption — "Ada is typing…" — for a chat header or the row
/// above the composer. Callers pass an already-localised [label].
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = color ?? theme.colorScheme.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TypingDots(color: tint),
        const SizedBox(width: AppSpacing.x2),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(color: tint),
          ),
        ),
      ],
    );
  }
}
