import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/permissions/media_permissions.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/notification/domain/entities/notification_preferences.dart';
import 'package:chatix/features/notification/presentation/providers/notification_preferences_provider.dart';
import 'package:chatix/features/notification/presentation/widgets/chat_notification_profile_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Sound, quiet hours, previews and the per-chat exceptions.
///
/// Every setting here is local. The backend stores devices, a list and a read
/// flag (api-docs §7) and has no opinion about any of this, so nothing on this
/// screen is sent anywhere — it is read again at the moment a notification is
/// about to be drawn, in the app or in the background isolate a push wakes up.
///
/// Not to be confused with a chat's own mute (`is_muted_by_me`, api-docs
/// §5.2), which lives in the chat's own screen and tells the *server* not to
/// send a push in the first place.
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final preferences = ref.watch(notificationPreferencesProvider);
    final controller = ref.read(notificationPreferencesProvider.notifier);
    final granted = ref.watch(notificationsEnabledProvider).value ?? true;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: ListView(
        key: const PageStorageKey<String>('notification-settings'),
        padding: const EdgeInsets.only(bottom: AppSpacing.x8),
        children: [
          if (!granted) const _PermissionBanner(),

          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.notificationSoundTitle),
            subtitle: Text(l10n.notificationSoundSubtitle),
            value: preferences.sound,
            onChanged: controller.setSound,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: Text(l10n.notificationVibrationTitle),
            subtitle: Text(l10n.notificationVibrationSubtitle),
            value: preferences.vibration,
            onChanged: controller.setVibration,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.chat_bubble_outline),
            title: Text(l10n.notificationPreviewTitle),
            subtitle: Text(l10n.notificationPreviewSubtitle),
            value: preferences.showPreview,
            onChanged: controller.setShowPreview,
          ),

          const Divider(),

          _SectionLabel(label: l10n.quietHoursTitle),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime_outlined),
            title: Text(l10n.quietHoursTitle),
            subtitle: Text(l10n.quietHoursSubtitle),
            value: preferences.quietHours.enabled,
            onChanged: controller.setQuietHoursEnabled,
          ),
          _QuietHourTile(
            label: l10n.quietHoursFrom,
            minute: preferences.quietHours.startMinute,
            enabled: preferences.quietHours.enabled,
            onChanged: (minute) => controller.setQuietHours(startMinute: minute),
          ),
          _QuietHourTile(
            label: l10n.quietHoursTo,
            minute: preferences.quietHours.endMinute,
            enabled: preferences.quietHours.enabled,
            onChanged: (minute) => controller.setQuietHours(endMinute: minute),
          ),

          const Divider(),

          _SectionLabel(label: l10n.chatNotificationsTitle),
          _ChatExceptions(preferences: preferences),
        ],
      ),
    );
  }
}

/// Says when the system grant is missing, because without it nothing on this
/// screen can take effect.
class _PermissionBanner extends ConsumerWidget {
  const _PermissionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      padding: const EdgeInsets.all(AppSpacing.x4),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  l10n.notificationPermissionOffTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            l10n.notificationPermissionOffHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () async {
                await ref.read(mediaPermissionsProvider).openSettings();
                ref.invalidate(notificationsEnabledProvider);
              },
              child: Text(l10n.callPermissionOpenSettings),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuietHourTile extends StatelessWidget {
  const _QuietHourTile({
    required this.label,
    required this.minute,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int minute;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay(hour: minute ~/ 60, minute: minute % 60);

    return ListTile(
      enabled: enabled,
      contentPadding: const EdgeInsets.only(
        left: AppSpacing.x8 + AppSpacing.x4,
        right: AppSpacing.x4,
      ),
      title: Text(label),
      trailing: Text(
        time.format(context),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
        );
        if (picked == null) return;
        onChanged(picked.hour * 60 + picked.minute);
      },
    );
  }
}

/// The chats that do not follow the settings above.
///
/// Only exceptions are listed: a row per chat would be a list of every chat
/// the reader has, which is what the chat's own screen is for.
class _ChatExceptions extends ConsumerWidget {
  const _ChatExceptions({required this.preferences});

  final NotificationPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final entries = preferences.chatProfiles.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          0,
          AppSpacing.x4,
          AppSpacing.x4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.chatNotificationsEmpty, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.x1),
            Text(
              l10n.chatNotificationsEmptyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final myUserId = ref.watch(authProvider).value?.id;
    final chats = ref.watch(chatListProvider).value?.items ?? const <ChatEntity>[];

    return Column(
      children: [
        for (final entry in entries)
          ListTile(
            leading: Icon(iconForChatNotificationProfile(entry.value)),
            title: Text(
              _titleFor(entry.key, chats, l10n, myUserId),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(chatNotificationProfileLabel(entry.value, l10n)),
            trailing: IconButton(
              tooltip: l10n.chatNotificationProfileAll,
              icon: const Icon(Icons.undo),
              onPressed: () => ref
                  .read(notificationPreferencesProvider.notifier)
                  .setChatProfile(entry.key, ChatNotificationProfile.all),
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
            child: TextButton(
              onPressed: ref
                  .read(notificationPreferencesProvider.notifier)
                  .clearChatProfiles,
              child: Text(l10n.chatNotificationsReset),
            ),
          ),
        ),
      ],
    );
  }

  /// The chat's name where the list has it, and the honest fallback where it
  /// does not: an exception can outlive a chat leaving the loaded page.
  static String _titleFor(
    String chatId,
    List<ChatEntity> chats,
    AppLocalizations l10n,
    int? myUserId,
  ) {
    for (final chat in chats) {
      if (chat.id == chatId) {
        return chatTitleOf(chat, l10n, myUserId: myUserId);
      }
    }
    return l10n.unknownChat;
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
