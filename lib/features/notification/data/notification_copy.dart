import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/features/notification/data/push_notification_presenter.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The wording a notification needs, taken from the ARB catalogue.
PushNotificationCopy pushCopyFrom(AppLocalizations l10n) =>
    PushNotificationCopy(
      appName: AppConstants.appName,
      newMessage: l10n.notificationNewMessage,
      replyLabel: l10n.messageReply,
      replyPlaceholder: l10n.notificationReplyHint,
      markReadLabel: l10n.markAsRead,
    );

/// The same wording, resolved without a `BuildContext`.
///
/// The background isolate that draws a push has no widget tree to read a
/// delegate off, but it can read the language the reader picked and load the
/// catalogue directly. Falls back to English rather than failing: a
/// notification in the wrong language beats no notification.
Future<PushNotificationCopy> loadPushCopy() async {
  return pushCopyFrom(await loadNotificationLocalizations());
}

Future<AppLocalizations> loadNotificationLocalizations() async {
  try {
    return await AppLocalizations.delegate.load(await _savedLocale());
  } on Object {
    return AppLocalizations.delegate.load(const Locale('en'));
  }
}

/// Mirrors what `savedLocaleProvider` reads, minus the provider graph.
const String _languageCodeKey = 'selected_language_code';

Future<Locale> _savedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_languageCodeKey);
    if (saved != null && AppLocalizations.delegate.isSupported(Locale(saved))) {
      return Locale(saved);
    }
  } on Object {
    // Falls through to the platform locale.
  }

  final platform = PlatformDispatcher.instance.locale;
  return AppLocalizations.delegate.isSupported(platform)
      ? platform
      : const Locale('en');
}
