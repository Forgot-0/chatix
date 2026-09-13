import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// What a transfer ring is currently saying.
enum TransferRingState {
  /// Bytes are moving. The ring fills, and the button in the middle stops it.
  running,

  /// The bytes are across but the other side has not signed off yet — the
  /// ring spins without a figure, because there is nothing to count.
  waiting,

  /// It did not work. The button in the middle tries again.
  failed,
}

/// A round progress badge over a thumbnail: the ring, the figure, and one
/// button in the middle.
///
/// Sits on its own scrim so it stays readable over any photo, and keeps the
/// same size in all three states so a transfer finishing does not make the
/// tile jump.
class TransferProgressRing extends StatelessWidget {
  const TransferProgressRing({
    super.key,
    required this.state,
    this.progress,
    this.onPressed,
    this.size = 48,
    this.semanticLabel,
  });

  final TransferRingState state;

  /// 0..1 while [state] is running, or null when the share is unknown.
  final double? progress;

  /// Cancel while running, retry once failed. A null callback leaves the
  /// badge as a pure indicator.
  final VoidCallback? onPressed;

  final double size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final value = state == TransferRingState.running ? progress : null;
    final icon = switch (state) {
      TransferRingState.running => Icons.close_rounded,
      TransferRingState.waiting => Icons.more_horiz_rounded,
      TransferRingState.failed => Icons.refresh_rounded,
    };

    final percent = state == TransferRingState.running && progress != null
        ? '${(progress!.clamp(0.0, 1.0) * 100).round()}%'
        : null;

    // White on a dark scrim rather than theme colours: the badge sits on a
    // photograph, which is neither a light nor a dark surface.
    final ring = SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: size, height: size),
          ),
          SizedBox(
            width: size - 6,
            height: size - 6,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 2.5,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: AlwaysStoppedAnimation<Color>(
                state == TransferRingState.failed ? scheme.error : Colors.white,
              ),
            ),
          ),
          if (onPressed == null)
            _Figure(percent: percent, icon: icon, size: size)
          else
            InkResponse(
              onTap: onPressed,
              radius: size / 2,
              child: _Figure(percent: percent, icon: icon, size: size),
            ),
        ],
      ),
    );

    final label = semanticLabel;
    if (label == null) return ring;

    return Semantics(
      button: onPressed != null,
      label: label,
      value: percent,
      child: ring,
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.percent, required this.icon, required this.size});

  final String? percent;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size - 14,
      height: size - 14,
      child: Center(
        child: percent == null
            ? Icon(icon, size: size * 0.38, color: Colors.white)
            : FittedBox(
                child: Text(
                  percent!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    height: 1,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The same badge as a flat row item, for a document that has no thumbnail
/// to sit on: a small ring with the figure beside it.
class TransferProgressBadge extends StatelessWidget {
  const TransferProgressBadge({
    super.key,
    required this.state,
    this.progress,
    this.onPressed,
    this.label,
  });

  final TransferRingState state;
  final double? progress;
  final VoidCallback? onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TransferProgressRing(
          state: state,
          progress: progress,
          onPressed: onPressed,
          size: 28,
        ),
        if (label != null) ...[
          const SizedBox(width: AppSpacing.x2),
          Text(label!, style: theme.textTheme.labelSmall),
        ],
      ],
    );
  }
}
