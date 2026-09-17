import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/presentation/providers/notification_preferences_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

String chatNotificationProfileLabel(
  ChatNotificationProfile profile,
  AppLocalizations l10n,
) {
  switch (profile) {
    case ChatNotificationProfile.all:
      return l10n.chatNotificationProfileAll;
    case ChatNotificationProfile.mentionsOnly:
      return l10n.chatNotificationProfileMentions;
    case ChatNotificationProfile.off:
      return l10n.chatNotificationProfileOff;
  }
}

IconData iconForChatNotificationProfile(ChatNotificationProfile profile) {
  switch (profile) {
    case ChatNotificationProfile.all:
      return Icons.notifications_active_outlined;
    case ChatNotificationProfile.mentionsOnly:
      return Icons.alternate_email;
    case ChatNotificationProfile.off:
      return Icons.notifications_off_outlined;
  }
}

/// Lets the reader say how much this one chat may interrupt.
///
/// Local, and deliberately separate from the chat's own mute: that one is
/// `PATCH /chats/{id}/state/` and stops the server sending a push at all
/// (api-docs §5.2), while this one decides what happens to a push that does
/// arrive — which is the only way to express "only when they mention me".
Future<void> showChatNotificationProfileSheet(
  BuildContext context,
  WidgetRef ref,
  String chatId,
) async {
  final l10n = AppLocalizations.of(context);
  final current = ref.read(notificationPreferencesProvider).profileFor(chatId);

  final choice = await showModalBottomSheet<ChatNotificationProfile>(
    context: context,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(l10n.chatNotificationProfileTitle),
            subtitle: Text(chatNotificationProfileLabel(current, l10n)),
          ),
          const Divider(height: 1),
          for (final profile in ChatNotificationProfile.values)
            ListTile(
              leading: Icon(iconForChatNotificationProfile(profile)),
              title: Text(chatNotificationProfileLabel(profile, l10n)),
              trailing: profile == current ? const Icon(Icons.check) : null,
              onTap: () => Navigator.of(sheetContext).pop(profile),
            ),
        ],
      ),
    ),
  );

  if (choice == null || choice == current) return;

  await ref
      .read(notificationPreferencesProvider.notifier)
      .setChatProfile(chatId, choice);
}
