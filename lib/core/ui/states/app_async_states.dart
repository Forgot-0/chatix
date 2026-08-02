library;
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chatix/core/error/failure_messages.dart';

/// The three states every list in this app can be in, drawn the same way
/// everywhere.
///
/// Before this file each screen invented its own trio: a bare
/// `CircularProgressIndicator` for loading, a centred `Text('No chats yet')`
/// for empty, and a hand-rolled `_ErrorView` copy-pasted between features
/// (there were four near-identical ones). The result was that the same
/// situation looked different depending on which tab you were in, and the
/// error text was always `failure.message` — the server's log-facing English
/// (api-docs §2.1) rather than something a user can act on.
///
/// So: [AppListSkeleton] while the first page is in flight, [AppEmptyState]
/// when the list came back empty, [AppErrorState] when it came back a
/// [Failure] — the last one running the error through
/// [friendlyFailureMessage] so `WRONG_LOGIN_DATA` reads as "Incorrect
/// username or password" instead of whatever the backend logs.
///
/// ### Why a skeleton and not a spinner
///
/// A spinner says "something is happening"; a skeleton says "a list of rows
/// is about to appear here, roughly this many, roughly this shape", which
/// makes the arrival of real content feel like a fill rather than a jump.
/// `shimmer` is already a dependency (it was pulled in for image
/// placeholders), so this costs nothing new.
///
/// ### First fetch only
///
/// These are meant for `AsyncValue.when`'s `loading` branch, which — with
/// riverpod's default `skipLoadingOnRefresh: true` — is only reached when
/// there is no previous data to show. A pull-to-refresh therefore keeps the
/// old rows on screen under the refresh spinner instead of flashing the
/// skeleton, which is the behaviour we want and the reason none of this
/// needs an explicit "isFirstLoad" flag.
///
/// ### Full-screen vs. inline
///
/// [AppListSkeleton]/[AppEmptyState]/[AppErrorState] size themselves to a
/// viewport (so they stay pull-to-refreshable). For a block *inside* an
/// already-scrolling parent — a tab's sub-list, the applications section of a
/// position page — use [AppInlineSkeleton]/[AppInlineEmpty]/[AppInlineError]:
/// same wording and same message pipeline, intrinsically sized, no scroll
/// view of their own.


/// A shimmering placeholder list shown while the **first** page loads.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({
    super.key,
    this.itemCount = 7,
    this.hasLeading = true,
    this.hasTrailing = false,
    this.lines = 2,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  /// Rows to draw. The default fills a phone screen without implying a
  /// specific page size — the point is the shape, not the count.
  final int itemCount;

  /// Draw a circular avatar placeholder on the left (chats, members,
  /// profiles) or not (plain text lists).
  final bool hasLeading;

  /// Draw a small block on the right (timestamps, chips, badges).
  final bool hasTrailing;

  /// 1 for a title-only row, 2 for title + subtitle.
  final int lines;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Shimmer needs two colours with enough contrast to read as motion but
    // not enough to read as content. Derived from the scheme so it works in
    // both light and dark themes instead of being hard-coded grey.
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = Color.alphaBlend(
      theme.colorScheme.surface.withValues(alpha: 0.6),
      base,
    );

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      // The skeleton is decoration, not information: a screen reader should
      // hear "loading", not seven empty list items.
      child: ExcludeSemantics(
        child: ListView.builder(
          // Never scrollable: it is a placeholder, and letting the user fling
          // it makes the swap to real content jarring.
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: itemCount,
          itemBuilder: (context, index) => _SkeletonRow(
            hasLeading: hasLeading,
            hasTrailing: hasTrailing,
            lines: lines,
            // Vary the title width per row so the block doesn't read as a
            // table of identical bars.
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
        // Shimmer paints its gradient over the child via a mask, so the
        // colour here only has to be opaque — the gradient supplies the hue.
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// "There is nothing here (yet)" — and, where possible, what to do about it.
///
/// Always scrollable so it can sit inside a [RefreshIndicator]: an empty list
/// is exactly the state a user is most likely to pull down on, and a
/// non-scrollable child silently disables that gesture.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  /// One short line: "No chats yet".
  final String title;

  /// Optional second line explaining how the list gets populated.
  final String? message;

  final IconData icon;

  /// Optional call to action ("New chat", "Browse projects").
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
                  Icon(
                    icon,
                    size: 56,
                    color: theme.colorScheme.outline,
                  ),
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
                  if (action != null) ...[
                    const SizedBox(height: 20),
                    action!,
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

/// The failure state for a list or a detail screen.
///
/// Takes the **raw error object** rather than a pre-formatted string on
/// purpose: given the object it can consult
/// [friendlyMessageForCode]/[friendlyFailureMessage] and turn an api-docs
/// error code into a sentence, whereas a caller that has already collapsed
/// the failure to `error.message` has thrown that information away.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    this.onRetry,
    this.fallbackMessage = 'Something went wrong. Please try again.',
    this.retryLabel = 'Retry',
  });

  /// Usually `AsyncValue.error`'s first argument, i.e. a `Failure`.
  final Object? error;

  /// Omitted when there is nothing sensible to retry.
  final VoidCallback? onRetry;

  /// Shown when [error] carries no usable message of its own.
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

/// The same failure, drawn for a **section inside** an already-scrolling
/// parent (a tab body's sub-list, the applications block on a position page).
///
/// [AppErrorState] cannot be used there. It sizes itself with a
/// `LayoutBuilder` + `ConstrainedBox(minHeight: constraints.maxHeight)` so it
/// can fill a viewport and stay pull-to-refreshable; as a child of a
/// `ListView` or `Column` the incoming `maxHeight` is `infinity` and that
/// same code throws. This variant is intrinsically sized and never scrolls,
/// which is what an embedded block needs.
///
/// Same message pipeline (`friendlyFailureMessage`), so a section failure
/// reads identically to a full-screen one.
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

/// The empty state for a section inside an already-scrolling parent — the
/// bounded-height counterpart of [AppEmptyState], for the same reason
/// [AppInlineError] is the counterpart of [AppErrorState].
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

/// A skeleton sized for a section rather than a viewport — a few rows, no
/// scroll view of its own, safe as a child of a `Column`/`ListView`.
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
              titleWidthFactor:
                  AppListSkeleton._titleWidths[index %
                      AppListSkeleton._titleWidths.length],
            ),
          ),
        ),
      ),
    );
  }
}

/// The trailing spinner row of an infinite-scroll list ("loading page 2").
///
/// Distinct from [AppListSkeleton] on purpose: the first fetch replaces the
/// whole viewport, a subsequent page appends one row — using the skeleton for
/// both would make an append look like a reload.
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
