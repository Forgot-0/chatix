import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';

/// One conversation: history + composer (api-docs §6.4, §6.5, §6.6).
///
/// ⚠️ **No live updates in this build.** Messages arrive only from
/// `GET /chats/{id}/messages/` — on open, on pull-to-refresh (which loads the
/// newest page) and on scroll-to-top (which pages *backwards* into history).
/// The WebSocket layer of api-docs §7 will push into the same controller
/// later; nothing here needs to change for that to work.
///
/// Which composer/action controls are shown is decided by the §9.1 permission
/// matrix through `canSendMessage` / `canEditMessage` / `canDeleteMessage`.
/// Those checks are UX only — the backend enforces them regardless.
class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// The list is `reverse: true`, so its *maxScrollExtent* end is the **oldest**
  /// message — reaching it means "load older history", the opposite direction
  /// from the chat list's pagination.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatDetailProvider(widget.chatId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(chatDetailProvider(widget.chatId));
    final myUserId = ref.watch(authProvider).value?.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(detail.value?.chat?.name ?? 'Chat'),
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: const Icon(Icons.call_outlined),
            onPressed: detail.value?.chat == null ? null : _joinCall,
          ),
          IconButton(
            tooltip: 'Members',
            icon: const Icon(Icons.people_outline),
            onPressed: () =>
                context.push(AppConstants.chatMembersRoute(widget.chatId)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: error is Failure ? error.message : 'Failed to load chat',
          onRetry: () =>
              ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) {
          final me = state.me;
          final canSend = canSendMessage(state.chat, me);

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(chatDetailProvider(widget.chatId).notifier)
                      .refresh(),
                  child: _MessageList(
                    state: state,
                    myUserId: myUserId,
                    scrollController: _scrollController,
                    chatId: widget.chatId,
                  ),
                ),
              ),
              if (state.replyTo != null)
                _ReplyBanner(
                  message: state.replyTo!,
                  onCancel: () => ref
                      .read(chatDetailProvider(widget.chatId).notifier)
                      .setReplyTo(null),
                ),
              _AttachmentBar(chatId: widget.chatId),
              _Composer(
                controller: _textController,
                enabled: canSend,
                // Explains *why* the composer is disabled — "you can't type
                // here" with no reason is the worst version of this state.
                disabledReason: _disabledReason(state.chat, me),
                onAttach: canSend ? _pickAttachments : null,
                onSend: canSend ? _send : null,
              ),
            ],
          );
        },
      ),
    );
  }

  String _disabledReason(ChatEntity? chat, ChatMemberEntity? me) {
    if (me == null) return 'Join this chat to send messages';
    if (me.isBanned) return 'You are banned from this chat';
    if (me.isMuted) return 'You are muted in this chat';
    if (chat?.adminOnly == true) return 'Only admins can post in this chat';
    return 'You do not have permission to send messages here';
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    final attachments = ref.read(chatAttachmentProvider(widget.chatId));

    // The server rejects a message with neither text nor attachments
    // (`400 INVALID_MESSAGE`); no point spending a request on it.
    if (text.isEmpty && !attachments.isReady) return;

    _textController.clear();

    await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .sendMessage(
          content: text.isEmpty ? null : text,
          // Tokens confirmed at step 3 can be used immediately — no waiting
          // for the WS `attachment_success` event (api-docs §6.5).
          uploadTokens: attachments.uploadTokens,
        );

    ref.read(chatAttachmentProvider(widget.chatId).notifier).clear();
  }

  /// Picks media through `image_picker`, filtered to the MIME types the
  /// backend accepts (api-docs §6.5). Size/count limits are enforced by
  /// `ChatAttachmentController.select` before anything is uploaded.
  Future<void> _pickAttachments() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isEmpty || !mounted) return;

    final uploads = <AttachmentUploadRequestEntity>[];
    for (final file in files) {
      final size = await file.length();
      final mime = file.mimeType ?? _mimeFromName(file.name);
      uploads.add(
        AttachmentUploadRequestEntity(
          filename: file.name,
          mimeType: mime,
          fileSize: size,
          filePath: file.path,
        ),
      );
    }

    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);
    notifier.select(uploads);

    // `select` rejects an invalid batch; only start the three-request upload
    // once the selection actually passed validation.
    if (ref.read(chatAttachmentProvider(widget.chatId)).hasSelection) {
      await notifier.upload();
    }
  }

  static String _mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      default:
        // Deliberately not guessed: an unknown type is rejected by
        // `ChatAttachmentLimits.typeOf` with a clear message rather than
        // uploaded under a wrong Content-Type (which the backend's async
        // validation would later mark `error`).
        return 'application/octet-stream';
    }
  }

  /// `POST /chats/{id}/calls/join/` (api-docs §6.6) — shows the LiveKit token
  /// and server URL. Actually joining the room needs the `livekit_client` SDK,
  /// which is out of scope here.
  Future<void> _joinCall() async {
    final result = await ref.read(joinCallUseCaseProvider).execute(widget.chatId);
    if (!mounted) return;

    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (token) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Call token'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Room: ${token.slug}'),
              const SizedBox(height: 8),
              Text('LiveKit URL: ${token.livekitUrl}'),
              const SizedBox(height: 8),
              const Text('Access token:'),
              const SizedBox(height: 4),
              SelectableText(
                token.token,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends ConsumerWidget {
  const _MessageList({
    required this.state,
    required this.myUserId,
    required this.scrollController,
    required this.chatId,
  });

  final ChatDetailState state;
  final int? myUserId;
  final ScrollController scrollController;
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.messages.isEmpty && state.pending.isEmpty) {
      return ListView(
        controller: scrollController,
        children: const [
          SizedBox(height: 120),
          Center(child: Text('No messages yet')),
        ],
      );
    }

    // Pending sends sit at index 0.. so they appear at the visual bottom of a
    // reversed list, i.e. after the newest confirmed message.
    final pendingCount = state.pending.length;
    final total =
        pendingCount + state.messages.length + (state.canLoadMore ? 1 : 0);

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      itemCount: total,
      itemBuilder: (context, index) {
        if (index < pendingCount) {
          final pending = state.pending[pendingCount - 1 - index];
          return _PendingBubble(pending: pending, chatId: chatId);
        }

        final messageIndex = index - pendingCount;
        if (messageIndex >= state.messages.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final message = state.messages[messageIndex];
        final notifier = ref.read(chatDetailProvider(chatId).notifier);
        final me = state.me;

        return MessageBubble(
          message: message,
          isMine: myUserId != null && message.authorId == myUserId,
          onReply: canSendMessage(state.chat, me)
              ? () => notifier.setReplyTo(message)
              : null,
          onForward: () => _forward(context, ref, message),
          // Only the author may edit, and there is no permission that grants
          // editing someone else's message (api-docs §9.1).
          onEdit: canEditMessage(me, message.authorId)
              ? () => _edit(context, ref, message)
              : null,
          onDelete: canDeleteMessage(state.chat, me, message.authorId)
              ? () => notifier.deleteMessage(message.id)
              : null,
          onOpenAttachment: (attachment) =>
              _openAttachment(context, ref, message, attachment),
        );
      },
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
  ) async {
    final controller = TextEditingController(text: message.content ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(controller: controller, maxLines: null),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;
    await ref
        .read(chatDetailProvider(chatId).notifier)
        .editMessage(message.id, result);
  }

  /// Forwards into another chat. ⚠️ The **destination** goes in the URL while
  /// the source pair travels in the body (api-docs §6.4) — the use case takes
  /// only named arguments so the two can't be swapped.
  Future<void> _forward(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
  ) async {
    final targetChatId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => _ForwardTargetDialog(
        excludeChatId: message.chatId,
      ),
    );
    if (targetChatId == null) return;

    final result = await ref
        .read(forwardMessageUseCaseProvider)
        .execute(
          sourceChatId: message.chatId,
          sourceMessageId: message.id,
          targetChatId: targetChatId,
        );

    if (!context.mounted) return;
    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (_) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Message forwarded'))),
    );
  }

  /// Download URLs live 300 s (api-docs §6.5), so one is requested per tap
  /// rather than cached with the attachment.
  Future<void> _openAttachment(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
    AttachmentEntity attachment,
  ) async {
    final result = await ref
        .read(getAttachmentDownloadUrlUseCaseProvider)
        .execute(message.chatId, message.id, attachment.id);

    if (!context.mounted) return;
    result.match(
      (failure) => ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message))),
      (download) => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(attachment.originalFilename),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Expires in ${download.expiresIn}s'),
              const SizedBox(height: 8),
              SelectableText(
                download.url,
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A send that hasn't been acknowledged yet. On failure it offers Retry, which
/// reuses the original `Idempotency-Key` — that is what makes the retry safe
/// rather than duplicating the message (api-docs §6.4).
class _PendingBubble extends ConsumerWidget {
  const _PendingBubble({required this.pending, required this.chatId});

  final PendingMessage pending;
  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(chatDetailProvider(chatId).notifier);
    final failed = pending.failure != null;

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: failed
              ? Border.all(color: theme.colorScheme.error)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (pending.content != null) Text(pending.content!),
            if (pending.uploadTokens.isNotEmpty)
              Text(
                '${pending.uploadTokens.length} attachment(s)',
                style: theme.textTheme.labelSmall,
              ),
            const SizedBox(height: 4),
            if (!failed)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      pending.failure!.message,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => notifier.retry(pending),
                    child: const Text('Retry'),
                  ),
                  TextButton(
                    onPressed: () => notifier.discard(pending),
                    child: const Text('Discard'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ReplyBanner extends StatelessWidget {
  const _ReplyBanner({required this.message, required this.onCancel});

  final MessageEntity message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.reply, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message.content ?? 'Attachment',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onCancel,
          ),
        ],
      ),
    );
  }
}

/// Progress/error strip for the attachment upload in flight (api-docs §6.5).
class _AttachmentBar extends ConsumerWidget {
  const _AttachmentBar({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatAttachmentProvider(chatId));
    final theme = Theme.of(context);

    if (state.failure != null) {
      return Container(
        width: double.infinity,
        color: theme.colorScheme.errorContainer,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(state.failure!.message)),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () =>
                  ref.read(chatAttachmentProvider(chatId).notifier).clear(),
            ),
          ],
        ),
      );
    }

    if (!state.hasSelection) return const SizedBox.shrink();

    final totalBytes = state.selected.fold<int>(
      0,
      (sum, upload) => sum + upload.fileSize,
    );

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${state.selected.length} file(s), '
                  '${ChatAttachmentLimits.formatBytes(totalBytes)}'
                  '${state.isReady ? ' — ready to send' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () =>
                    ref.read(chatAttachmentProvider(chatId).notifier).clear(),
              ),
            ],
          ),
          if (state.isUploading)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: state.progress?.fraction,
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.disabledReason,
    this.onAttach,
    this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final String disabledReason;
  final VoidCallback? onAttach;
  final Future<void> Function()? onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!enabled) {
      return SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: theme.colorScheme.surfaceContainerHighest,
          child: Text(
            disabledReason,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Attach',
              icon: const Icon(Icons.attach_file),
              onPressed: onAttach,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                // `SendMessageRequest.content` caps at 4096 (api-docs §6.4);
                // the counter makes the limit visible instead of surprising.
                maxLength: 4096,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Message',
                  border: OutlineInputBorder(),
                  counterText: '',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: onSend == null ? null : () => onSend!(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks which chat to forward into, reusing the already-loaded chat list.
class _ForwardTargetDialog extends ConsumerWidget {
  const _ForwardTargetDialog({required this.excludeChatId});

  final String excludeChatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatListProvider);

    return AlertDialog(
      title: const Text('Forward to'),
      content: SizedBox(
        width: double.maxFinite,
        child: chats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text('Could not load chats'),
          data: (state) {
            final targets = state.items
                .where((chat) => chat.id != excludeChatId)
                .toList();
            if (targets.isEmpty) return const Text('No other chats');
            return ListView.builder(
              shrinkWrap: true,
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final chat = targets[index];
                return ListTile(
                  title: Text(chat.name ?? 'Chat'),
                  onTap: () => Navigator.of(context).pop(chat.id),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
