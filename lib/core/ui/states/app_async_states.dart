library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The shimmer every skeleton in the app sweeps with.
///
/// Wrap a layout of [AppBone]s in it. Two things it does that a bare
/// [Shimmer] does not: it takes its colours from the theme, so a skeleton is
/// right in both themes without the caller thinking about it, and it stops
/// sweeping when the reader has asked for less motion — a loading placeholder
/// is the last thing that should be pulsing at somebody who turned animation
/// off. The bones are still there; they simply hold still.
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: Color.alphaBlend(
        scheme.surface.withValues(alpha: 0.6),
        base,
      ),
      period: AppMotion.loop,
      enabled: !context.prefersReducedMotion,
      child: ExcludeSemantics(child: child),
    );
  }
}

/// One rectangle of a skeleton: where a line of text or a thumbnail will be.
///
/// Painted white on purpose — [AppSkeleton] is what gives it its colour, and
/// the shimmer gradient needs an opaque child to mask.
class AppBone extends StatelessWidget {
  const AppBone({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadii.sm,
    this.margin,
  });

  final double? width;
  final double height;
  final double radius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 7,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.lines = 2,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final int itemCount;

  final bool hasLeading;

  final bool hasTrailing;

  final int lines;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, index) => _SkeletonRow(
          hasLeading: hasLeading,
          hasTrailing: hasTrailing,
          lines: lines,
          titleWidthFactor: _titleWidths[index % _titleWidths.length],
        ),
      ),
    );
  }

  static const List<double> _titleWidths = [0.55, 0.4, 0.7, 0.48, 0.62];
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({
    required this.hasLeading,
    required this.hasTrailing,
    required this.lines,
    required this.titleWidthFactor,
  });

  final bool hasLeading;
  final bool hasTrailing;
  final int lines;
  final double titleWidthFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLeading) ...[
            const AppBone(width: 40, height: 40, radius: AppRadii.full),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: titleWidthFactor,
                  child: const AppBone(height: 14),
                ),
                if (lines > 1) ...[
                  const SizedBox(height: 8),
                  const FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.85,
                    child: AppBone(height: 11),
                  ),
                ],
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            const AppBone(width: 32, height: 12),
          ],
        ],
      ),
    );
  }
}

/// Nothing to show, said properly.
///
/// The picture is a drawing rather than an icon wherever the caller can name
/// what the screen is empty of — see [AppIllustrationKind]. A 56 px outlined
/// glyph is what a list looks like when it has failed to load; a drawing is
/// what it looks like when it is simply new, and telling those two apart
/// without reading is most of this widget's job.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.illustration,
    this.action,
  });

  final String title;

  final String? message;

  /// Drawn only when [illustration] is null — the fallback for a state
  /// nobody has drawn a picture for yet.
  final IconData icon;

  /// What the screen is empty of. Preferred over [icon].
  final AppIllustrationKind? illustration;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (illustration case final kind?)
                    AppIllustration(kind: kind)
                  else
                    Icon(icon, size: 56, color: theme.colorScheme.outline),
                  const SizedBox(height: AppSpacing.x4),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (action != null) ...[const SizedBox(height: 20), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.fallbackMessage,
    this.retryLabel,
  });

  final Object? error;

  final VoidCallback? onRetry;

  /// This screen's own wording for "it did not load", used when the failure
  /// carries no code anybody has a sentence for. Null falls back to the
  /// generic one, in the reader's language.
  final String? fallbackMessage;

  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final message = friendlyFailureMessage(
      error,
      l10n: l10n,
      fallback: fallbackMessage,
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (onRetry != null) ...[
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh),
                      label: Text(retryLabel ?? l10n.retry),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppInlineError extends StatelessWidget {
  const AppInlineError({
    super.key,
    required this.error,
    this.onRetry,
    this.fallbackMessage,
  });

  final Object? error;
  final VoidCallback? onRetry;

  /// See [AppErrorState.fallbackMessage].
  final String? fallbackMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = friendlyFailureMessage(
      error,
      l10n: AppLocalizations.of(context),
      fallback: fallbackMessage,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 32, color: theme.colorScheme.error),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ],
      ),
    );
  }
}

class AppInlineEmpty extends StatelessWidget {
  const AppInlineEmpty({
    super.key,
    required this.title,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppInlineSkeleton extends StatelessWidget {
  const AppInlineSkeleton({
    super.key,
    this.itemCount = 3,
    this.hasLeading = true,
    this.lines = 2,
  });

  final int itemCount;
  final bool hasLeading;
  final int lines;

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          itemCount,
          (index) => _SkeletonRow(
            hasLeading: hasLeading,
            hasTrailing: false,
            lines: lines,
            titleWidthFactor: AppListSkeleton
                ._titleWidths[index % AppListSkeleton._titleWidths.length],
          ),
        ),
      ),
    );
  }
}

class AppLoadMoreIndicator extends StatelessWidget {
  const AppLoadMoreIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
