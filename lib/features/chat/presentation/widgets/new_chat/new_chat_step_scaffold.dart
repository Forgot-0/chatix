import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/theme/app_tokens.dart';

/// A step of "new group" / "new channel": the title — with a count under
/// it when there is one — the way forward at the right of the app bar, and
/// on a phone the same way forward again as a round button under the thumb.
///
/// Whether this is "a phone" is the width this screen was given, not the
/// window's: a pane is narrower than its window.
class NewChatStepScaffold extends StatelessWidget {
  const NewChatStepScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    required this.body,
    this.busy = false,
  });

  final String title;
  final String? subtitle;

  /// "Next" or "Create".
  final String actionLabel;

  /// An arrow for "Next", a tick for "Create".
  final IconData actionIcon;

  final VoidCallback onAction;
  final Widget body;

  /// The create is on the wire: both buttons spin, and going back waits.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = subtitle;

    return PopScope(
      canPop: !busy,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < AppBreakpoints.medium;

          return Scaffold(
            appBar: AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (line != null)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: AppSpacing.x2),
                  child: busy
                      ? const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppSpacing.x4,
                          ),
                          child: SizedBox.square(
                            dimension: AppSpacing.x5,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : TextButton(
                          onPressed: onAction,
                          child: Text(actionLabel),
                        ),
                ),
              ],
            ),
            floatingActionButton: isPhone
                ? FloatingActionButton(
                    heroTag: null,
                    tooltip: actionLabel,
                    onPressed: busy ? null : onAction,
                    child: busy
                        ? SizedBox.square(
                            dimension: AppSpacing.x6,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          )
                        : Icon(actionIcon),
                  )
                : null,
            body: body,
          );
        },
      ),
    );
  }
}
