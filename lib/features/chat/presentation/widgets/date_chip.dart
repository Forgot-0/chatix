import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';

/// The "Today" / "12 May" capsule that floats over a conversation.
///
/// The fill is translucent and the backdrop behind it is blurred, so the chip
/// stays readable while it sits on top of messages — which is what a sticky
/// header does most of the time. Sticking it to the top of the list is the
/// list's job; this widget only knows how to look right while it is up there.
class DateChip extends StatelessWidget {
  const DateChip({
    super.key,
    required this.label,
    this.visible = true,
    this.blurred = true,
    this.elevated = false,
  });

  final String label;

  /// Fades the chip out rather than removing it, so a list can show it while
  /// scrolling and hide it once the scroll settles.
  final bool visible;

  /// Blur costs a saveLayer. Off for the inline separators between day
  /// groups, which sit on the wallpaper and have nothing to blur.
  final bool blurred;

  /// Lifts the chip off the conversation with a shadow. What the sticky
  /// header turns on while the list is moving, so it reads as floating over
  /// the messages rather than sitting between them.
  final bool elevated;

  static const double _blurSigma = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    final capsule = ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: _maybeBlur(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x3,
            vertical: AppSpacing.x1 + 1,
          ),
          color: chatix.dateChip,
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppMotion.base,
        curve: AppMotion.curve,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.curve,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.full),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : const [],
          ),
          child: capsule,
        ),
      ),
    );
  }

  Widget _maybeBlur({required Widget child}) {
    if (!blurred) return child;
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: _blurSigma, sigmaY: _blurSigma),
      child: child,
    );
  }
}
