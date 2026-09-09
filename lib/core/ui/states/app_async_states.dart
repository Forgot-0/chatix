library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chatix/core/error/failure_messages.dart';

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
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: 0.6),
      base,
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ExcludeSemantics(
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
            const _Bone(width: 40, height: 40, radius: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: titleWidthFactor,
                  child: const _Bone(height: 14),
                ),
                if (lines > 1) ...[
                  const SizedBox(height: 8),
                  const FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.85,
                    child: _Bone(height: 11),
                  ),
                ],
              ],
            ),
          ),
          if (hasTrailing) ...[
            const SizedBox(width: 12),
            const _Bone(width: 32, height: 12),
          ],
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;

  final String? message;

  final IconData icon;

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
                  Icon(icon, size: 56, color: theme.colorScheme.outline),
                  const SizedBox(height: 16),
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
    this.fallbackMessage = 'Something went wrong. Please try again.',
    this.retryLabel = 'Retry',
  });

  final Object? error;

  final VoidCallback? onRetry;

  final String fallbackMessage;

  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = friendlyFailureMessage(error, fallback: fallbackMessage);

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
                      label: Text(retryLabel),
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
    this.fallbackMessage = 'Something went wrong. Please try again.',
  });

  final Object? error;
  final VoidCallback? onRetry;
  final String fallbackMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = friendlyFailureMessage(error, fallback: fallbackMessage);

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
              label: const Text('Retry'),
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
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: 0.6),
      base,
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: ExcludeSemantics(
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
