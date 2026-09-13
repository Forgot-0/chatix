import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';

/// Transient messages that are not worth interrupting anyone for.
abstract final class AppSnackbar {
  /// A note that something small did not work, shown briefly and then gone.
  ///
  /// For failures the reader did not ask about and cannot act on — an
  /// optimistic change the server refused, a background retry that gave up.
  /// It carries no action, it never queues behind another (a burst of
  /// failures is one message, not six), and it sits on a surface colour
  /// rather than the inverse one so it reads as a footnote rather than an
  /// alert.
  ///
  /// Does nothing outside a [ScaffoldMessenger], so callers do not have to
  /// care whether the screen still exists.
  static void quiet(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    messenger
      ..hideCurrentSnackBar(reason: SnackBarClosedReason.remove)
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurface),
          ),
          backgroundColor: scheme.surfaceContainerHighest,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          width: _width,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.full),
            side: BorderSide(color: scheme.outlineVariant),
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
}
