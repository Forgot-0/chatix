import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// A chip arriving under a message.
///
/// Reactions land the moment they are tapped — the request has not answered
/// yet — so the entrance is what tells the reader the tap registered. It
/// overshoots slightly and settles, which reads as the emoji opening rather
/// than a box being drawn.
///
/// Plays once, when the widget is first built. The row keys its chips by
/// emoji, so a chip that was already there survives a rebuild and does not
/// bloom again while its count changes.
class ReactionBloom extends StatefulWidget {
  const ReactionBloom({super.key, required this.child});

  final Widget child;

  static const Duration duration = Duration(milliseconds: 320);

  @override
  State<ReactionBloom> createState() => _ReactionBloomState();
}

class _ReactionBloomState extends State<ReactionBloom>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ReactionBloom.duration,
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 0.4,
        end: 1.12,
      ).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.12,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 35,
    ),
  ]).animate(_controller);

  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Reduced motion gets the chip, not the entrance.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(opacity: _opacity, child: widget.child),
    );
  }
}

/// The scatter of colour the very first reaction on a message throws off.
///
/// Only the first: a message that already has chips gains another one
/// quietly, and a feed where every count change threw particles would be
/// unreadable. [play] is flipped by whoever is watching the message go from
/// no reactions to some.
class ReactionBurst extends StatefulWidget {
  const ReactionBurst({
    super.key,
    required this.play,
    required this.fromRight,
    required this.child,
  });

  /// Flipped to true on the frame the message gains its first reaction.
  final bool play;

  /// Outgoing messages sit against the right edge, so their chips — and the
  /// burst — start there.
  final bool fromRight;

  final Widget child;

  static const Duration duration = Duration(milliseconds: 620);

  static const int particleCount = 12;

  @override
  State<ReactionBurst> createState() => _ReactionBurstState();
}

class _ReactionBurstState extends State<ReactionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: ReactionBurst.duration,
  );

  /// Fixed at birth: a burst that re-rolled its angles on every frame would
  /// shimmer instead of travelling.
  late final List<_Particle> _particles = _spawn();

  /// A burst asked for before the widget has its inherited widgets.
  ///
  /// The row is only in the tree once there is a chip to draw, so the first
  /// reaction on a message builds this widget already wanting to play —
  /// which is one frame before `MediaQuery` can be read.
  bool _pending = false;

  @override
  void initState() {
    super.initState();
    _pending = widget.play;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_pending) return;
    _pending = false;
    _start();
  }

  @override
  void didUpdateWidget(ReactionBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) _start();
  }

  void _start() {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static List<_Particle> _spawn() {
    // Seeded rather than random so a golden of this widget is stable, and so
    // two bursts on screen at once do not have to agree.
    final random = math.Random(ReactionBurst.particleCount);

    return [
      for (var i = 0; i < ReactionBurst.particleCount; i++)
        _Particle(
          // Fanned upwards and outwards, with enough jitter that the twelve
          // do not read as spokes on a wheel.
          angle:
              -math.pi / 2 +
              (i / (ReactionBurst.particleCount - 1) - 0.5) * math.pi * 1.1 +
              (random.nextDouble() - 0.5) * 0.25,
          distance: 22 + random.nextDouble() * 26,
          radius: 1.6 + random.nextDouble() * 2.2,
          tint: i % 3,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return CustomPaint(
      foregroundPainter: _BurstPainter(
        progress: _controller,
        particles: _particles,
        fromRight: widget.fromRight,
        tints: [scheme.primary, scheme.tertiary, scheme.secondary],
      ),
      child: widget.child,
    );
  }
}

class _Particle {
  const _Particle({
    required this.angle,
    required this.distance,
    required this.radius,
    required this.tint,
  });

  final double angle;
  final double distance;
  final double radius;

  /// Index into the painter's three colours.
  final int tint;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.particles,
    required this.fromRight,
    required this.tints,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<_Particle> particles;
  final bool fromRight;
  final List<Color> tints;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    if (t <= 0 || t >= 1) return;

    // Out fast, then coast — the opposite of the chip, which settles.
    final travel = Curves.easeOutCubic.transform(t);
    final fade = t < 0.6 ? 1.0 : 1 - (t - 0.6) / 0.4;

    final origin = Offset(
      fromRight ? size.width - AppSpacing.x6 : AppSpacing.x6,
      size.height / 2,
    );

    for (final particle in particles) {
      final reach = particle.distance * travel;
      final centre =
          origin +
          Offset(
            math.cos(particle.angle) * reach,
            math.sin(particle.angle) * reach +
                // A little gravity on the way out, so they arc.
                12 * travel * travel,
          );

      canvas.drawCircle(
        centre,
        particle.radius * (1 - travel * 0.55),
        Paint()
          ..color = tints[particle.tint % tints.length].withValues(
            alpha: fade.clamp(0, 1),
          )
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.particles != particles ||
      oldDelegate.fromRight != fromRight ||
      oldDelegate.tints != tints;
}
