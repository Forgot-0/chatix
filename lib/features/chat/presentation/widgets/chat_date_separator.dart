import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/date_chip.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The day label that sits between two days of conversation.
class ChatDateSeparator extends StatelessWidget {
  const ChatDateSeparator({super.key, required this.date});

  final DateTime date;

  /// "Today", "Yesterday", or the date itself — the same wording the sticky
  /// header uses, so the two never disagree about what day it is.
  static String label(BuildContext context, DateTime value) {
    final l10n = AppLocalizations.of(context);
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(local.year, local.month, local.day);

    final delta = today.difference(that).inDays;
    if (delta == 0) return l10n.dateToday;
    if (delta == 1) return l10n.dateYesterday;

    return MaterialLocalizations.of(context).formatMediumDate(local);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2 + 2),
        // Inline between day groups: it sits on the wallpaper, so there is
        // nothing behind it worth blurring.
        child: DateChip(label: label(context, date), blurred: false),
      ),
    );
  }
}

/// The day label that rides the top of the feed.
///
/// It names the day of whatever row is currently under the top edge, so the
/// reader always knows where they are in a long scroll back. It only appears
/// while the list is moving: parked over a settled conversation it would be
/// one more thing covering a message.
class ChatStickyDate extends StatelessWidget {
  const ChatStickyDate({super.key, required this.day, required this.isMoving});

  /// Null before the first frame has been measured, and for a feed with no
  /// messages in it.
  final ValueListenable<DateTime?> day;

  final ValueListenable<bool> isMoving;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: ValueListenableBuilder<DateTime?>(
          valueListenable: day,
          builder: (context, value, _) {
            if (value == null) return const SizedBox.shrink();

            return ValueListenableBuilder<bool>(
              valueListenable: isMoving,
              builder: (context, moving, _) => DateChip(
                label: ChatDateSeparator.label(context, value),
                visible: moving,
                elevated: moving,
              ),
            );
          },
        ),
      ),
    );
  }
}
