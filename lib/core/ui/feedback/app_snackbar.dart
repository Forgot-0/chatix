import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/haptics.dart';

/// Transient messages that are not worth interrupting anyone for.
abstract final class AppSnackbar {
  /// A note that something small happened, shown briefly and then gone.
  ///
  /// For outcomes the reader does not need to act on — a copy that landed, a
  /// cache that was cleared, a change that saved. It carries no action, it
  /// never queues behind another (a burst is one message, not six), and it
  /// sits on a surface colour rather than the inverse one so it reads as a
  /// footnote rather than an alert. Anything that *failed* goes through
  /// [failure] instead.
  ///
  /// Does nothing outside a [ScaffoldMessenger], so callers do not have to
  /// care whether the screen still exists.
  static void quiet(BuildContext context, String message) =>
      _show(context, message, failed: false);

  /// The same note, for something that did not work.
  ///
  /// Separate from [quiet] not because it looks very different — it is the
  /// same footnote in the same place, tinted — but because a failure is the
  /// one thing here worth *feeling*: the reader may well be looking at the
  /// composer rather than at the bottom of the screen, and a toast they miss
  /// is a toast that did not happen. Everything that reports a refused or
  /// failed action goes through here, so that "the app buzzes when something
  /// went wrong" is true everywhere rather than in the four places somebody
  /// remembered.
  static void failure(BuildContext context, String message) =>
      _show(context, message, failed: true);

  static void _show(
    BuildContext context,
    String message, {
    required bool failed,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    if (failed) AppHaptics.error();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    messenger
      ..hideCurrentSnackBar(reason: SnackBarClosedReason.remove)
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: failed ? scheme.error : scheme.onSurface,
            ),
          ),
          backgroundColor: scheme.surfaceContainerHighest,
          duration: _visibleFor,
          behavior: SnackBarBehavior.floating,
          width: _width,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
            side: BorderSide(
              color: failed ? scheme.error : scheme.outlineVariant,
            ),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
        ),
      );
  }

  /// Narrow enough to read as a toast rather than a bar across the app.
  static const double _width = 280;

  /// How long it stays.
  ///
  /// Not a motion token: this is reading time for a short sentence, which is
  /// a property of the sentence rather than of the app's animation scale.
  static const Duration _visibleFor = Duration(seconds: 2);
}
