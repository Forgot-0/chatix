import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/file_revealer.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/haptics.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/recent_reactions_provider.dart';
import 'package:chatix/features/chat/presentation/utils/attachment_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_feed_items.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/forward_flow.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_date_separator.dart';
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
    required this.onDelete,
  });

  final String chatId;
  final FeedMessageItem item;
  final ChatDetailState state;

  final bool selectionMode;
  final bool isSelected;

  final void Function(String messageId) onStartSelection;
  final void Function(String messageId) onToggleSelected;
  final void Function(MessageEntity message) onEdit;

  /// Asks before deleting, and says so if the server refuses. The screen's,
  /// so that one message from its menu and a whole selection from the bar
  /// go through the same question and the same report.
  final void Function(String messageId) onDelete;

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

    // The document the menu's save, share and show-in-folder act on, once
    // the gateway has confirmed it — before that there is nothing to fetch.
    final confirmed = ref.watch(confirmedAttachmentTokensProvider);
    final document = message.attachments
        .where(
          (a) =>
              a.attachmentType == AttachmentType.file &&
              (a.attachmentStatus == AttachmentStatus.success ||
                  (a.attachmentStatus != AttachmentStatus.error &&
                      confirmed.contains(a.id))),
        )
        .firstOrNull;
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
      showAuthor: item.showsAuthor,
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
        hasDocument: document != null,
        canShareFiles: ref.watch(fileSharerProvider).isSupported,
        canRevealFiles: ref.watch(fileRevealerProvider).isSupported,
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
              // The one place a reaction is put on or taken off, whichever
              // of the four ways it was asked for — double tap, the menu's
              // row, the picker, or tapping the chip.
              AppHaptics.reactionToggled();
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
        groups: state.reactionsFor(message.id).groups,
        members: state.chat?.members ?? const [],
      ),
      onReply: canSendMessage(state.chat, me)
          ? () => notifier.setReplyTo(message)
          : null,
      onForward: () => _forward(context, ref, message),
      onCopy: () => _copy(context, message),
      onSaveFile: document == null
          ? null
          : () => AttachmentActions.saveDocument(
              context,
              ref,
              attachment: document,
              messageId: message.id,
            ),
      onShareFile: document == null
          ? null
          : () => AttachmentActions.share(
              context,
              ref,
              attachment: document,
              messageId: message.id,
            ),
      onShowInFolder: document == null
          ? null
          : () => AttachmentActions.showInFolder(
              context,
              ref,
              attachment: document,
              messageId: message.id,
            ),
      onShowDetails: () => MessageDetailsSheet.show(
        context,
        message: message,
        deliveryStatus: deliveryStatus,
      ),
      onEdit: canEditMessage(me, message.authorId)
          ? () => onEdit(message)
          : null,
      onDelete: canDeleteMessage(state.chat, me, message.authorId)
          ? () => onDelete(message.id)
          : null,
      onOpenAttachment: (attachment) =>
          _openAttachment(context, ref, message, attachment),
      onRetryAttachment: () => notifier.refreshMessage(message.id),
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

  /// The full catalog, for when the quick bar does not have it.
  ///
  /// Recents lead the sheet for the same reason they lead the bar, and the
  /// policy is handed down whole so a chat in `reactions_mode = "some"`
  /// narrows the catalog rather than the sheet having to know about modes.
  Future<void> _pickReaction(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
    ChatReactionPolicy policy,
  ) async {
    final emoji = await ReactionPicker.show(
      context,
      reactions: state.reactionsFor(message.id),
      policy: policy,
      recent: ref.read(recentReactionsProvider),
    );
    if (emoji == null) return;

    ref.read(recentReactionsProvider.notifier).remember(emoji);
    ref
        .read(chatDetailProvider(chatId).notifier)
        .toggleReaction(message.id, emoji);
  }

  Future<void> _forward(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
  ) => ForwardFlow.start(context, ref, message: message);

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

  /// Opens what was tapped.
  ///
  /// Photos and videos go to the viewer, which carries the tile across with
  /// a Hero and lets the rest of the chat's media be swiped through.
  /// Anything else is handed to the platform.
  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
    AttachmentEntity attachment,
  ) async {
    final isMedia =
        attachment.attachmentType == AttachmentType.image ||
        attachment.attachmentType == AttachmentType.video;

    if (isMedia) {
      await context.push<void>(
        ChatMediaRoute(
          message.chatId,
          messageId: message.id,
          attachmentId: attachment.id,
        ).location,
      );
      return;
    }

    await AttachmentActions.open(
      context,
      ref,
      attachment: attachment,
      messageId: message.id,
    );
  }
}

/// Just enough of a member to route to their profile.
typedef ChatMemberLike = ({int userId});

/// Holds the left gutter open for incoming messages in a group chat.
///
/// Every row of the run keeps the space, so its bubbles stay in one column;
/// only the last one puts the author's face in it, level with the bottom of
/// its bubble. The name stays on the first bubble — it is read first, the
/// face is where the run ends.
class _WithAvatarGutter extends StatelessWidget {
  const _WithAvatarGutter({required this.item, required this.child});

  final FeedMessageItem item;
  final Widget child;

  static const ChatAvatarSize _size = ChatAvatarSize.sm;

  @override
  Widget build(BuildContext context) {
    final gutter = ChatLayout.avatarGutterFor(_size.diameter);

    final bubble = Padding(
      // The bubble keeps its own side margin, so only the rest of the gutter
      // is added here.
      padding: EdgeInsets.only(left: gutter - ChatLayout.bubbleInsetX),
      child: child,
    );

    if (!item.showsAvatar) return bubble;

    // The bubble is laid out first and the face pinned to its foot, rather
    // than the two sharing a row: a bottom-aligned row would size itself to
    // the taller of them, and the face is never what should decide that.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        bubble,
        Positioned(
          left: ChatLayout.avatarInset,
          bottom: 0,
          child: ChatAvatar.profile(
            item.message.profile,
            userId: item.message.authorId,
            size: _size,
          ),
        ),
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
