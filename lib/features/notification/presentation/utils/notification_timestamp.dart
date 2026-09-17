import 'package:flutter/material.dart' show MaterialLocalizations;

import 'package:chatix/gen/l10n/app_localizations.dart';

/// How long ago a notification arrived, in words.
///
/// Rounds down at every step, which is what makes it read as a timestamp
/// rather than a countdown: something 119 seconds old is "just now", not "2
/// min ago". Anything older than a week is a date, because "38 days ago" is a
/// number nobody converts.
String formatNotificationTimestamp(
  DateTime timestamp,
  AppLocalizations l10n,
  MaterialLocalizations material, {
  DateTime? now,
}) {
  final local = timestamp.toLocal();
  final difference = (now ?? DateTime.now()).difference(local);

  // A clock that is behind the server's reads as the future; "just now" is a
  // better answer than a negative count.
  if (difference.inMinutes < 1) return l10n.timeJustNow;
  if (difference.inHours < 1) return l10n.timeMinutesAgo(difference.inMinutes);
  if (difference.inDays < 1) return l10n.timeHoursAgo(difference.inHours);
  if (difference.inDays < 7) return l10n.timeDaysAgo(difference.inDays);

  return material.formatMediumDate(local);
}
