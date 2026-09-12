import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/recent_reactions_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_feed_items.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_date_separator.dart';
import 'package:chatix/features/chat/presentation/widgets/forward_target_dialog.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/message_details_sheet.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_users_sheet.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/features/chat/presentation/widgets/unread_divider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One row of the conversation: the bubble, plus whatever separates it from
/// the message above.
///
/// Everything it needs to know about its place in the feed — whether it heads
/// a run, closes one, opens a day or crosses the read cursor — is decided in
/// [ChatFeedBuilder] and arrives resolved, so the row itself never looks at
/// its neighbours.
///
/// It is also where rights turn into affordances: [MessageActions] builds the
/// menu from `chat_permissions`, and every callback below is null wherever
/// the matching right is missing, so the bubble cannot offer what the server
/// would refuse.
class ChatMessageRow extends ConsumerWidget {
  const ChatMessageRow({
    super.key,
    required this.chatId,
    required this.item,
    required this.state,
    required this.selectionMode,
    required this.isSelected,
    required this.onStartSelection,
    required this.onToggleSelected,
    required this.onEdit,
  });

  final String chatId;
  final FeedMessageItem item;
  final ChatDetailState state;

  final bool selectionMode;
  final bool isSelected;

  final void Function(String messageId) onStartSelection;
  final void Function(String messageId) onToggleSelected;
  final void Function(MessageEntity message) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = item.message;
    final notifier = ref.read(chatDetailProvider(chatId).notifier);
    final me = state.me;
    final policy = state.chat?.reactionPolicy;

    // Recents decide the order of the quick bar and what a double tap sends,
    // so the gesture matches the habit rather than a fixed default.
    ref.watch(recentReactionsProvider);
    final quickReactions = policy == null || !policy.enabled
        ? const <String>[]
        : ref.read(recentReactionsProvider.notifier).ordered(policy.isAllowed);

    final canReact = quickReactions.isNotEmpty;
    final deliveryStatus = resolveDeliveryStatus(
      isMine: item.isMine,
      isDirect: state.chat?.type == ChatType.direct,
      isPending: false,
      seq: message.seq,
      peerReadSeq: state.peerReadCursor,
    );

    final bubble = MessageBubble(
      message: message,
      isMine: item.isMine,
      isFirstInGroup: item.startsGroup,
      isLastInGroup: item.endsGroup,
      showAuthor: item.showsAvatar,
      showMeta: item.endsGroup,
      selectionMode: selectionMode,
      isSelected: isSelected,
      onSelectionToggled: () => onToggleSelected(message.id),
      onStartSelection: () => onStartSelection(message.id),
      actions: MessageActions.of(
        chat: state.chat,
        me: me,
        message: message,
        canReact: canReact,
        canSelect: !selectionMode,
      ),
      reactions: state.reactionsFor(message.id),
      quickReactions: quickReactions,
      isHighlighted: state.highlightMessageId == message.id,
      deliveryStatus: deliveryStatus,
      isKnownMention: (handle) => _memberFor(handle) != null,
      onOpenLink: (link) => _openLink(context, link),
      onJumpToOriginal: message.isReply
          ? () => _jumpToOriginal(context, ref, message)
          : null,
      onToggleReaction: canReact
          ? (emoji) {
              ref.read(recentReactionsProvider.notifier).remember(emoji);
              notifier.toggleReaction(message.id, emoji);
            }
          : null,
      onShowReactionPicker: canReact
          ? () => _pickReaction(context, ref, message, policy!)
          : null,
      onShowReactionUsers: (emoji) => ReactionUsersSheet.show(
        context,
        chatId: chatId,
        messageId: message.id,
        emoji: emoji,
        members: state.chat?.members ?? const [],
      ),
      onReply: canSendMessage(state.chat, me)
          ? () => notifier.setReplyTo(message)
          : null,
      onForward: () => _forward(context, ref, message),
      onCopy: () => _copy(context, message),
      onShowDetails: () => MessageDetailsSheet.show(
        context,
        message: message,
        deliveryStatus: deliveryStatus,
      ),
      onEdit: canEditMessage(me, message.authorId)
          ? () => onEdit(message)
          : null,
      onDelete: canDeleteMessage(state.chat, me, message.authorId)
          ? () => notifier.deleteMessage(message.id)
          : null,
      onOpenAttachment: (attachment) =>
          _openAttachment(context, ref, message, attachment),
    );

    // Its own layer: a bubble redraws when its reactions or ticks change, and
    // there is no reason for the rest of a thousand-message list to redraw
    // with it.
    final Widget row = RepaintBoundary(
      child: item.hasAvatarGutter
          ? _WithAvatarGutter(item: item, child: bubble)
          : bubble,
    );

    if (!item.showsDate && !item.showsUnread) return row;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.showsDate) ChatDateSeparator(date: item.message.createdAt),
        if (item.showsUnread) const ChatUnreadSeparator(),
        row,
      ],
    );
  }

  /// The person an `@handle` names, when they are in this conversation.
  ///
  /// Usernames may contain spaces (api-docs §4.2), so no pattern can reliably
  /// end one; matching against the roster is what makes a mention real, and
  /// what keeps an unresolvable handle from becoming a link to nowhere.
  ChatMemberLike? _memberFor(String handle) {
    final wanted = handle.toLowerCase();
    for (final member in state.chat?.members ?? const []) {
      final username = member.profile?.username?.trim().toLowerCase();
      if (username != null && username == wanted) {
        return (userId: member.userId);
      }
    }
    return null;
  }

  Future<void> _openLink(BuildContext context, LinkSpan link) async {
    if (link.kind == MessageLinkKind.mention) {
      final member = _memberFor(link.target);
      if (member == null) return;
      context.push(ProfileDetailRoute(member.userId).location);
      return;
    }

    final uri = Uri.tryParse(link.target);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkOpenFailed)),
    );
  }

  void _copy(BuildContext context, MessageEntity message) {
    final content = message.content;
    if (content == null || content.isEmpty) return;

    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).messageCopied)),
    );
  }

  Future<void> _pickReaction(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
    ChatReactionPolicy policy,
  ) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ReactionPicker(
          reactions: state.reactionsFor(message.id),
          policy: policy,
          onSelected: (value) => Navigator.of(sheetContext).pop(value),
        ),
      ),
    );
    if (emoji == null) return;

    ref.read(recentReactionsProvider.notifier).remember(emoji);
    ref.read(chatDetailProvider(chatId).notifier).toggleReaction(
      message.id,
      emoji,
    );
  }

  Future<void> _forward(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
  ) async {
    final target = await ForwardTargetDialog.pick(
      context,
      excludeChatId: message.chatId,
    );
    if (target == null) return;

    final result = await ref
        .read(forwardMessageUseCaseProvider)
        .execute(
          sourceChatId: message.chatId,
          sourceMessageId: message.id,
          targetChatId: target.chatId,
          comment: target.comment,
        );

    if (!context.mounted) return;
    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).messageForwarded)),
      ),
    );
  }

  Future<void> _jumpToOriginal(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
  ) async {
    final targetId = message.replyToId ?? message.replyTo?.id;
    if (targetId == null) return;

    final ok = await ref
        .read(chatDetailProvider(chatId).notifier)
        .revealMessage(targetId, seq: message.replyTo?.seq);

    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).messageNotFound)),
    );
  }

  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
    AttachmentEntity attachment,
  ) async {
    if (attachment.attachmentType == AttachmentType.image) {
      await AttachmentViewer.open(
        context,
        attachment: attachment,
        messageId: message.id,
      );
      return;
    }

    final result = await ref
        .read(getAttachmentDownloadUrlUseCaseProvider)
        .execute(message.chatId, message.id, attachment.id);

    if (!context.mounted) return;

    final failureMessage = AppLocalizations.of(context).attachmentOpenFailed;

    await result.match(
      (failure) async => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (download) async {
        final uri = Uri.tryParse(download.url);
        final opened =
            uri != null &&
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (opened || !context.mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failureMessage)));
      },
    );
  }
}

/// Just enough of a member to route to their profile.
typedef ChatMemberLike = ({int userId});

/// Holds the left gutter open for incoming messages in a group chat.
///
/// The face goes on the first message of a run only; the rest of the run
/// keeps the space so the bubbles stay in one column under it.
class _WithAvatarGutter extends StatelessWidget {
  const _WithAvatarGutter({required this.item, required this.child});

  final FeedMessageItem item;
  final Widget child;

  static const double _gutter = 44;

  @override
  Widget build(BuildContext context) {
    final density = ChatixTheme.of(context).density;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _gutter,
          child: item.showsAvatar
              ? Padding(
                  // Lines the face up with the top of the bubble, which
                  // carries the run's own leading gap.
                  padding: EdgeInsets.only(
                    top: density.groupGap,
                    left: AppSpacing.x3,
                  ),
                  child: ChatAvatar.profile(
                    item.message.profile,
                    userId: item.message.authorId,
                    size: ChatAvatarSize.xs,
                  ),
                )
              : null,
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// The line a conversation is split on: everything below it is new.
class ChatUnreadSeparator extends StatelessWidget {
  const ChatUnreadSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    return UnreadDivider(label: AppLocalizations.of(context).unreadMessages);
  }
}
