import 'package:equatable/equatable.dart';

/// How much a single chat is allowed to interrupt.
///
/// Not the same thing as `is_muted_by_me` (api-docs §5.2), which is a server
/// column the backend consults before it sends a push at all, and not remotely
/// the same thing as `MemberChatDTO.is_muted`, which is a moderator silencing
/// somebody. This is the reader's own local answer to "what do I want to see
/// from this chat", applied when a notification is about to be drawn.
enum ChatNotificationProfile {
  /// Every message.
  all,

  /// Only messages that name the reader.
  mentionsOnly,

  /// Nothing.
  off;

  static ChatNotificationProfile fromName(String? value) =>
      ChatNotificationProfile.values.firstWhere(
        (profile) => profile.name == value,
        orElse: () => ChatNotificationProfile.all,
      );
}

/// A nightly window in which notifications arrive without a sound.
///
/// Stored as minutes since midnight, local time, so it survives a timezone
/// change the way a wall clock does: "quiet from 23:00" means 23:00 wherever
/// the reader happens to be.
class QuietHours extends Equatable {
  const QuietHours({
    this.enabled = false,
    this.startMinute = 23 * 60,
    this.endMinute = 7 * 60,
  });

  final bool enabled;

  final int startMinute;

  final int endMinute;

  static const int minutesPerDay = 24 * 60;

  /// Whether [minuteOfDay] falls inside the window.
  ///
  /// The window is allowed to wrap past midnight — that is the usual case —
  /// so this is not a plain range check. Start equal to end is read as "all
  /// day", which is the only reading that lets the reader express it.
  bool containsMinute(int minuteOfDay) {
    final minute = minuteOfDay % minutesPerDay;
    final start = startMinute % minutesPerDay;
    final end = endMinute % minutesPerDay;

    if (start == end) return true;
    if (start < end) return minute >= start && minute < end;
    return minute >= start || minute < end;
  }

  /// Whether the window is on and [moment] falls inside it.
  bool isActiveAt(DateTime moment) =>
      enabled && containsMinute(moment.hour * 60 + moment.minute);

  QuietHours copyWith({bool? enabled, int? startMinute, int? endMinute}) =>
      QuietHours(
        enabled: enabled ?? this.enabled,
        startMinute: startMinute ?? this.startMinute,
        endMinute: endMinute ?? this.endMinute,
      );

  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'startMinute': startMinute,
    'endMinute': endMinute,
  };

  static QuietHours fromJson(Map<String, Object?> json) => QuietHours(
    enabled: json['enabled'] == true,
    startMinute: _minute(json['startMinute'], 23 * 60),
    endMinute: _minute(json['endMinute'], 7 * 60),
  );

  static int _minute(Object? value, int fallback) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse('${value ?? ''}');
    if (parsed == null || parsed < 0 || parsed >= minutesPerDay) {
      return fallback;
    }
    return parsed;
  }

  @override
  List<Object?> get props => [enabled, startMinute, endMinute];
}

/// Everything the reader has said about how notifications should behave.
///
/// Local only: the backend has no endpoint for any of it (api-docs §7 knows
/// about devices, a list and a read flag, and nothing else), so this is read
/// at the moment a notification is about to be drawn rather than sent
/// anywhere.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.sound = true,
    this.vibration = true,
    this.showPreview = true,
    this.quietHours = const QuietHours(),
    this.chatProfiles = const <String, ChatNotificationProfile>{},
  });

  final bool sound;

  final bool vibration;

  /// Whether the message text is shown, or only who it is from.
  final bool showPreview;

  final QuietHours quietHours;

  /// Only the chats that differ from [ChatNotificationProfile.all]; the map
  /// is a list of exceptions, not a row per chat.
  final Map<String, ChatNotificationProfile> chatProfiles;

  ChatNotificationProfile profileFor(String? chatId) {
    if (chatId == null || chatId.isEmpty) return ChatNotificationProfile.all;
    return chatProfiles[chatId] ?? ChatNotificationProfile.all;
  }

  NotificationPreferences copyWith({
    bool? sound,
    bool? vibration,
    bool? showPreview,
    QuietHours? quietHours,
    Map<String, ChatNotificationProfile>? chatProfiles,
  }) {
    return NotificationPreferences(
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      showPreview: showPreview ?? this.showPreview,
      quietHours: quietHours ?? this.quietHours,
      chatProfiles: chatProfiles ?? this.chatProfiles,
    );
  }

  /// [ChatNotificationProfile.all] drops the entry rather than storing it, so
  /// resetting a chat leaves nothing behind.
  NotificationPreferences withChatProfile(
    String chatId,
    ChatNotificationProfile profile,
  ) {
    final next = Map<String, ChatNotificationProfile>.from(chatProfiles);
    if (profile == ChatNotificationProfile.all) {
      next.remove(chatId);
    } else {
      next[chatId] = profile;
    }
    return copyWith(chatProfiles: next);
  }

  Map<String, Object?> toJson() => {
    'sound': sound,
    'vibration': vibration,
    'showPreview': showPreview,
    'quietHours': quietHours.toJson(),
    'chatProfiles': {
      for (final entry in chatProfiles.entries) entry.key: entry.value.name,
    },
  };

  static NotificationPreferences fromJson(Map<String, Object?> json) {
    final rawQuiet = json['quietHours'];
    final rawProfiles = json['chatProfiles'];

    return NotificationPreferences(
      sound: json['sound'] != false,
      vibration: json['vibration'] != false,
      showPreview: json['showPreview'] != false,
      quietHours: rawQuiet is Map
          ? QuietHours.fromJson(Map<String, Object?>.from(rawQuiet))
          : const QuietHours(),
      chatProfiles: rawProfiles is Map
          ? {
              for (final entry in rawProfiles.entries)
                if (entry.key is String && '${entry.key}'.isNotEmpty)
                  '${entry.key}': ChatNotificationProfile.fromName(
                    entry.value is String ? entry.value as String : null,
                  ),
            }
          : const <String, ChatNotificationProfile>{},
    );
  }

  @override
  List<Object?> get props => [
    sound,
    vibration,
    showPreview,
    quietHours,
    chatProfiles,
  ];
}
