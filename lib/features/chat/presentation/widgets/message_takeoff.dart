import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';

/// The flight a sent message makes from the composer into the feed.
///
/// A message that simply *appears* at the bottom of the list reads as
/// something the server did. A message that leaves the box, rises, and
/// settles reads as something you did — and it is the only confirmation the
/// composer can honestly give, since the send has not been answered yet when
/// this plays.
///
/// The physical claim is modest on purpose: the pending bubble is already
/// drawn directly above the composer, on the same side of the screen as the
/// send button, so the whole flight is a short rise from just below the
/// bubble's resting place plus a scale up about the corner it came from. No
/// overlay, no global keys, no coordinates measured across two widgets —
/// which is what keeps it from breaking the moment the keyboard changes the
/// composer's height.
///
/// Plays once, on the frame the widget is first built. The feed keys pending
/// rows by their idempotency key, so a bubble that is retrying or waiting is
/// the same widget and does not take off again.
class MessageTakeoff extends StatefulWidget {
  const MessageTakeoff({super.key, required this.child, this.fromRight = true});

  final Widget child;

  /// Which corner the bubble grows from — the side the composer's send
  /// button is on, which is the side outgoing messages sit on.
  final bool fromRight;

  /// How far below its resting place the bubble starts, in logical pixels.
  ///
  /// About the height of the composer's own padding: enough to read as
  /// coming *from* down there, short enough that it never looks like the
  /// list scrolled.
  static const double travel = 28;

  /// The size it starts at. Not tiny — this is a bubble leaving a box, not
  /// something being born.
  static const double fromScale = 0.86;

  @override
  State<MessageTakeoff> createState() => _MessageTakeoffState();
}

class _MessageTakeoffState extends State<MessageTakeoff>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.expressive,
  );

  /// Rise and settle: [AppMotion.arrive] overshoots a little at the top, so
  /// the bubble lands rather than stops.
  late final Animation<double> _rise = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.arrive,
  );

  /// The fade is over well before the movement is, so what is read is a
  /// bubble moving rather than a bubble materialising.
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.4, curve: AppMotion.curve),
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    // Reduced motion gets the message, not the flight.
    if (context.prefersReducedMotion) {
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _rise.value;

        return Opacity(
          opacity: _fade.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, MessageTakeoff.travel * (1 - t)),
            child: Transform.scale(
              scale:
                  MessageTakeoff.fromScale + (1 - MessageTakeoff.fromScale) * t,
              // Grown about the corner nearest the composer's button, so the
              // movement has a source rather than a centre.
              alignment: widget.fromRight
                  ? Alignment.bottomRight
                  : Alignment.bottomLeft,
              child: child,
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}
