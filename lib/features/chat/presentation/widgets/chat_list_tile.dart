import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/rbac/permission_helpers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_swipe_actions.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart'
    show chatFailureMessage;
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/search_history_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_preview.dart';
import 'package:chatix/features/chat/presentation/utils/chat_timestamp.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/utils/open_chat.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_type_glyph.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a chat row can do to the chat it stands for.
///
/// Only [ChatRowAction.delete] reaches the server; the rest are this device's
/// own bookkeeping, because `/chats/` has no field for any of them. Pinning
/// and archiving belong to the chat organizer, which enforces the pinned
/// zone's limit; silencing stays with the chat feature's own prefs.
enum ChatRowAction { markRead, pin, archive, mute, delete }

/// One conversation in the chats list.
///
/// Everything on the row comes from the list response — `ChatDTO` carries
/// `last_message`, `unread_count` and `me` (api-docs §5.2) — except two
/// things: the presence dot, which costs a member request per direct chat and
/// is cached in [chatPresenceProvider], and the draft, which only ever existed
/// on this device.
class ChatListTile extends ConsumerStatefulWidget {
  const ChatListTile({
    super.key,
    required this.chat,
    this.isSelected = false,
    this.peerReadSeq,
    this.enableActions = true,
  });

  final ChatEntity chat;

  /// Whether this chat is the one open in the detail pane.
  final bool isSelected;

  /// How far the other side has read, when we have been told — the second
  /// tick is a lie without it. Direct chats only; see [resolveDeliveryStatus].
  final int? peerReadSeq;

  /// Swipe and long-press actions. Off where a row is a search result rather
  /// than the list itself.
  final bool enableActions;

  @override
  ConsumerState<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends ConsumerState<ChatListTile> {
  @override
  void initState() {
    super.initState();
    _requestPresence();
  }

  @override
  void didUpdateWidget(covariant ChatListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) _requestPresence();
  }

  /// Asks once per row that comes into view. The cache behind it decides
  /// whether that turns into a request at all.
  void _requestPresence() {
    if (widget.chat.type != ChatType.direct) return;
    ref.read(chatPresenceProvider.notifier).ensureFresh(widget.chat.id);
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);

    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final prefs = ref.watch(chatLocalPrefsProvider);
    final organizer = ref.watch(organizerDataProvider);
    final draft = ref.watch(chatDraftProvider(chat.id));

    final isMuted = prefs.isMuted(chat.id);
    final isPinned = organizer.isPinned(chat.id);
    final isArchived = organizer.isArchived(chat.id);
    final unread = chat.unreadCount ?? 0;

    final preview = chatPreviewOf(chat, l10n, draft: draft, myUserId: myUserId);

    final row = Material(
      color: widget.isSelected
          ? scheme.secondaryContainer
          : Colors.transparent,
      child: InkWell(
        onTap: () => openChat(context, ref, chat.id),
        onLongPress: widget.enableActions
            ? () => _openMenu(prefs, organizer, myUserId)
            : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x2 + chatix.density.listRowPadding,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChatRowAvatar(chat: chat, myUserId: myUserId),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TitleLine(
                      chat: chat,
                      myUserId: myUserId,
                      peerReadSeq: widget.peerReadSeq,
                      isUnread: unread > 0 && !isMuted,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _PreviewLine(preview: preview),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        _RowMarkers(
                          unread: unread,
                          isMuted: isMuted,
                          isPinned: isPinned,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!widget.enableActions) return row;

    return AppSwipeActions(
      leading: [_muteAction(l10n, scheme, isMuted: isMuted)],
      trailing: [
        if (unread > 0)
          SwipeAction(
            icon: Icons.mark_chat_read_outlined,
            label: l10n.markAsRead,
            background: scheme.secondaryContainer,
            foreground: scheme.onSecondaryContainer,
            onPressed: _markRead,
          ),
        SwipeAction(
          icon: isArchived
              ? Icons.unarchive_outlined
              : Icons.archive_outlined,
          label: isArchived ? l10n.unarchiveChat : l10n.archiveChat,
          background: chatix.attention,
          foreground: AppContrast.foregroundOn(chatix.attention),
          onPressed: _toggleArchive,
        ),
        SwipeAction(
          icon: isPinned
              ? Icons.push_pin
              : Icons.push_pin_outlined,
          label: isPinned ? l10n.unpinChat : l10n.pinChat,
          background: scheme.primaryContainer,
          foreground: scheme.onPrimaryContainer,
          onPressed: _togglePin,
        ),
      ],
      child: row,
    );
  }

  SwipeAction _muteAction(
    AppLocalizations l10n,
    ColorScheme scheme, {
    required bool isMuted,
  }) {
    return SwipeAction(
      icon: isMuted
          ? Icons.notifications_active_outlined
          : Icons.notifications_off_outlined,
      label: isMuted ? l10n.unmuteChat : l10n.muteChat,
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
      onPressed: _toggleMute,
    );
  }

  Future<void> _markRead() async {
    final ok = await ref
        .read(chatListProvider.notifier)
        .markChatRead(widget.chat.id);

    // The badge has already come back on its own; say why.
    if (!ok && mounted) _toast(AppLocalizations.of(context).errorOccurred);
  }

  /// Pins the chat, or says why it could not be: the zone holds five, and
  /// which of them to let go of is not ours to decide.
  Future<void> _togglePin() async {
    final failure = await ref
        .read(chatOrganizerProvider.notifier)
        .togglePin(widget.chat.id);

    if (failure == null || !mounted) return;

    final l10n = AppLocalizations.of(context);
    _toast(
      failure is PinLimitFailure
          ? l10n.pinLimitReached(failure.limit)
          : l10n.errorOccurred,
    );
  }

  void _toggleMute() {
    ref
        .read(chatLocalPrefsProvider.notifier)
        .toggle(ChatLocalFlag.muted, widget.chat.id);
  }

  Future<void> _toggleArchive() async {
    final controller = ref.read(chatOrganizerProvider.notifier);
    final wasArchived = ref
        .read(organizerDataProvider)
        .isArchived(widget.chat.id);

    final failure = await controller.setArchived(
      widget.chat.id,
      archived: !wasArchived,
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context);

    if (failure != null) {
      _toast(l10n.errorOccurred);
      return;
    }

    if (wasArchived) {
      _toast(l10n.chatUnarchivedToast);
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.chatArchivedToast),
          action: SnackBarAction(
            label: l10n.undo,
            onPressed: () =>
                controller.setArchived(widget.chat.id, archived: false),
          ),
        ),
      );
  }

  Future<void> _openMenu(
    ChatLocalPrefs prefs,
    ChatOrganizerData organizer,
    int? myUserId,
  ) async {
    final chat = widget.chat;
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final unread = chat.unreadCount ?? 0;
    final canDelete = hasChatPermission(
      chat,
      chat.me,
      ChatPermissions.chatDelete,
    );

    final choice = await showModalBottomSheet<ChatRowAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x4,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chatTitleOf(chat, l10n, myUserId: myUserId),
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              ListTile(
                leading: const Icon(Icons.mark_chat_read_outlined),
                title: Text(l10n.markAsRead),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ChatRowAction.markRead),
              ),
            ListTile(
              leading: Icon(
                organizer.isPinned(chat.id)
                    ? Icons.push_pin
                    : Icons.push_pin_outlined,
              ),
              title: Text(
                organizer.isPinned(chat.id) ? l10n.unpinChat : l10n.pinChat,
              ),
              onTap: () => Navigator.of(sheetContext).pop(ChatRowAction.pin),
            ),
            ListTile(
              leading: Icon(
                organizer.isArchived(chat.id)
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(
                organizer.isArchived(chat.id)
                    ? l10n.unarchiveChat
                    : l10n.archiveChat,
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatRowAction.archive),
            ),
            ListTile(
              leading: Icon(
                prefs.isMuted(chat.id)
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_off_outlined,
              ),
              title: Text(
                prefs.isMuted(chat.id) ? l10n.unmuteChat : l10n.muteChat,
              ),
              onTap: () => Navigator.of(sheetContext).pop(ChatRowAction.mute),
            ),
            // `DELETE /chats/{id}/` needs `chat:delete`, which only an owner
            // has (api-docs §8.1). Offering it to anyone else would be a
            // button that always fails.
            if (canDelete) ...[
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.error),
                title: Text(
                  l10n.deleteChat,
                  style: TextStyle(color: scheme.error),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ChatRowAction.delete),
              ),
            ],
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case ChatRowAction.markRead:
        await _markRead();
      case ChatRowAction.pin:
        await _togglePin();
      case ChatRowAction.archive:
        await _toggleArchive();
      case ChatRowAction.mute:
        _toggleMute();
      case ChatRowAction.delete:
        await _confirmAndDelete();
    }
  }

  Future<void> _confirmAndDelete() async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteChat),
        content: Text(l10n.deleteChatConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteChat),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await ref
        .read(deleteChatUseCaseProvider)
        .execute(widget.chat.id);

    if (!mounted) return;

    result.match(
      (failure) => _toast(
        chatFailureMessage(failure) ??
            friendlyFailureMessage(failure, fallback: l10n.errorOccurred),
      ),
      (_) {
        ref.read(chatListProvider.notifier).removeLocally(widget.chat.id);
        ref.read(chatLocalPrefsProvider.notifier).forget(widget.chat.id);
        ref.read(chatOrganizerProvider.notifier).forget(widget.chat.id);
        ref.read(searchHistoryProvider.notifier).forgetChat(widget.chat.id);
        _toast(l10n.chatDeletedToast);
      },
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

/// The face on a chat row: the other person in a direct chat, a mosaic of
/// members in a group, its initial where the list gave us no roster.
///
/// Public because the search results draw the same rows and should not
/// invent a second way of picturing a chat.
class ChatRowAvatar extends ConsumerWidget {
  const ChatRowAvatar({
    super.key,
    required this.chat,
    required this.myUserId,
  });

  final ChatEntity chat;
  final int? myUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final title = chatTitleOf(chat, l10n, myUserId: myUserId);

    if (chat.type != ChatType.direct) {
      final faces = _facesOf(chat, myUserId);

      // A group the list gave us no roster for still deserves a face of its
      // own: its initial on its own colour, not the same grey glyph as every
      // other group on the screen.
      if (faces.isEmpty) {
        return ChatAvatar(
          userId: chat.id.hashCode,
          name: title,
          size: ChatAvatarSize.md,
        );
      }

      return ChatAvatarMosaic(faces: faces, size: ChatAvatarSize.md);
    }

    final peer = chat.peerProfile(myUserId);
    final isOnline = ref.watch(chatPeerOnlineProvider(chat.id));
    final avatarUrl = peer?.avatarUrl;

    return ChatAvatar(
      source: avatarUrl == null || avatarUrl.isEmpty
          ? AvatarSource.none
          : AvatarSource.url(avatarUrl, cacheKey: peer?.avatarS3Key),
      userId: peer?.userId ?? chat.id.hashCode,
      // The peer's own profile when the row carries one; the row's title
      // otherwise, which for a direct chat is that same person's name.
      name: peer?.bestName ?? title,
      size: ChatAvatarSize.md,
      isOnline: isOnline,
      onlineLabel: l10n.onlineNow,
    );
  }

  /// Faces for a group's mosaic avatar.
  ///
  /// The list endpoint does not always carry a roster, and a group that has
  /// its own `avatar_s3_key` does not need one; both cases fall through to
  /// the type icon that [ChatAvatarMosaic] draws when handed nothing.
  static List<AvatarFace> _facesOf(ChatEntity chat, int? myUserId) {
    final roster = chat.members;
    if (roster == null) return const [];

    return [
      for (final member in roster)
        if (member.userId != myUserId && member.profile != null)
          AvatarFace.profile(member.profile!),
    ];
  }
}

class _TitleLine extends StatelessWidget {
  const _TitleLine({
    required this.chat,
    required this.myUserId,
    required this.peerReadSeq,
    required this.isUnread,
  });

  final ChatEntity chat;
  final int? myUserId;
  final int? peerReadSeq;
  final bool isUnread;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final status = _statusOf();
    final stamp = chat.lastActivityAt;

    return Row(
      children: [
        if (chat.type != ChatType.direct) ...[
          ChatTypeGlyph(
            type: chat.type,
            semanticLabel: chatTypeLabel(chat.type, l10n),
          ),
          const SizedBox(width: AppSpacing.x2 - 2),
        ],
        Expanded(
          child: Text(
            chatTitleOf(chat, l10n, myUserId: myUserId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (status != null) ...[
          const SizedBox(width: AppSpacing.x2),
          StatusTicks(status: status, size: 15),
        ],
        if (stamp != null) ...[
          const SizedBox(width: AppSpacing.x1 + 2),
          Text(
            formatChatTimestamp(
              stamp,
              l10n,
              locale: Localizations.localeOf(context).toLanguageTag(),
            ),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isUnread ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: isUnread ? FontWeight.w600 : null,
            ),
          ),
        ],
      ],
    );
  }

  /// Ticks belong on the row only when the last word was yours.
  MessageDeliveryStatus? _statusOf() {
    final message = chat.lastMessage;
    if (message == null || myUserId == null) return null;
    if (message.authorId != myUserId) return null;

    return resolveDeliveryStatus(
          isMine: true,
          isDirect: chat.type == ChatType.direct,
          isPending: false,
          seq: message.seq,
          peerReadSeq: peerReadSeq,
        ) ??
        // A group has no honest read state, but "sent" is still true there.
        MessageDeliveryStatus.sent;
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.preview});

  final ChatPreview preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);

    final base = theme.textTheme.bodyMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      height: 1.2,
    );

    final spans = <InlineSpan>[
      if (preview.isDraft)
        TextSpan(
          text: '${AppLocalizations.of(context).draftLabel} ',
          style: base?.copyWith(
            color: chatix.danger,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (preview.author != null)
        TextSpan(
          text: '${preview.author}: ',
          style: base?.copyWith(color: scheme.onSurface),
        ),
      TextSpan(text: preview.body),
    ];

    final text = Text.rich(
      TextSpan(children: spans),
      style: base,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final icon = preview.icon;
    if (icon == null) return text;

    return Row(
      children: [
        Icon(icon, size: 15, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.x1 + 1),
        Expanded(child: text),
      ],
    );
  }
}

/// The pin, the crossed-out bell and the unread count, in that order.
class _RowMarkers extends StatelessWidget {
  const _RowMarkers({
    required this.unread,
    required this.isMuted,
    required this.isPinned,
  });

  final int unread;
  final bool isMuted;
  final bool isPinned;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    if (!isPinned && !isMuted && unread == 0) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMuted)
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.x1),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 15,
              color: scheme.onSurfaceVariant,
              semanticLabel: l10n.chatMutedLabel,
            ),
          ),
        if (isPinned && unread == 0)
          Icon(
            Icons.push_pin,
            size: 15,
            color: scheme.onSurfaceVariant,
            semanticLabel: l10n.chatPinnedLabel,
          ),
        if (unread > 0) UnreadBadge(count: unread, isMuted: isMuted),
      ],
    );
  }
}

/// The unread pill.
///
/// A silenced chat keeps its count — you still want to know — but drops to the
/// neutral fill, so a screen full of badges still shows which ones are asking
/// for you.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count, this.isMuted = false});

  final int count;
  final bool isMuted;

  /// Anything above this is drawn as "999+"; the row has no width for more.
  static const int cap = 999;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final background = isMuted
        ? scheme.surfaceContainerHighest
        : scheme.primary;
    final foreground = isMuted ? scheme.onSurfaceVariant : scheme.onPrimary;

    return Semantics(
      label: AppLocalizations.of(context).unreadMessagesCount(count),
      child: Container(
        constraints: const BoxConstraints(minWidth: 20),
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.full),
        ),
        alignment: Alignment.center,
        child: Text(
          count > cap ? '$cap+' : '$count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
