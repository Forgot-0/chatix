import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The way back down to the live end of a conversation.
///
/// It only appears once the reader is properly away from the bottom — far
/// enough that scrolling back by hand is a chore — and counts what has
/// arrived below them while they were up there.
class ChatJumpToBottomButton extends StatelessWidget {
  const ChatJumpToBottomButton({
    super.key,
    required this.newBelow,
    required this.onPressed,
  });

  /// Null while the reader is near the bottom and the button is not wanted.
  /// A number, including zero, means show it with that badge.
  final ValueListenable<int?> newBelow;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return ValueListenableBuilder<int?>(
      valueListenable: newBelow,
      builder: (context, count, child) {
        final visible = count != null;

        return AnimatedSlide(
          duration: ChatixTheme.duration,
          curve: ChatixTheme.curve,
          offset: visible ? Offset.zero : const Offset(0, 1.4),
          child: AnimatedOpacity(
            duration: ChatixTheme.duration,
            opacity: visible ? 1 : 0,
            child: IgnorePointer(
              ignoring: !visible,
              child: Semantics(
                label: l10n.newMessagesBelow(count ?? 0),
                button: true,
                child: Padding(
                  padding: const EdgeInsets.only(right: 4, bottom: 4),
                  child: Badge(
                    isLabelVisible: count != null && count > 0,
                    label: Text(
                      count != null && count > 99 ? '99+' : '${count ?? 0}',
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      child: FloatingActionButton.small(
        heroTag: null,
        tooltip: l10n.scrollToBottom,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 2,
        onPressed: onPressed,
        child: const Icon(Icons.arrow_downward),
      ),
    );
  }
}
