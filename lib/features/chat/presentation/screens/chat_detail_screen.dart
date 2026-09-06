import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/core/router/app_routes.dart';

enum _AttachmentSource { media, document }

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  Set<String>? _selectedMessageIds;

  bool get _selectionMode => _selectedMessageIds != null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _startSelection(String messageId) {
    setState(() => _selectedMessageIds = {messageId});
  }

  void _toggleSelected(String messageId) {
    setState(() {
      final selected = _selectedMessageIds;
      if (selected == null) return;
      if (!selected.remove(messageId)) selected.add(messageId);
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessageIds = null);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildSelectionAppBar(ChatDetailState? state) {
    final selected = _selectedMessageIds ?? const <String>{};
    final canDelete =
        state != null &&
        selected.isNotEmpty &&
        selected.every((id) {
          final message = _findMessage(state, id);
          return message != null &&
              canDeleteMessage(state.chat, state.me, message.authorId);
        });

    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel',
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text('${selected.length} selected'),
      actions: [
        IconButton(
          tooltip: 'Forward',
          icon: const Icon(Icons.forward),
          onPressed: selected.isEmpty ? null : _forwardSelected,
        ),
        IconButton(
          tooltip: 'Delete',
          icon: const Icon(Icons.delete_outline),
          onPressed: canDelete ? _deleteSelected : null,
        ),
      ],
    );
  }

  MessageEntity? _findMessage(ChatDetailState state, String messageId) {
    for (final message in state.messages) {
      if (message.id == messageId) return message;
    }
    return null;
  }

  Future<void> _forwardSelected() async {
    final state = ref.read(chatDetailProvider(widget.chatId)).value;
    final selected = _selectedMessageIds;
    if (state == null || selected == null || selected.isEmpty) return;

    final targetChatId = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _ForwardTargetDialog(excludeChatId: widget.chatId),
    );
    if (targetChatId == null || !mounted) return;

    final ordered = state.messages
        .where((message) => selected.contains(message.id))
        .toList()
        .reversed
        .toList();

    final useCase = ref.read(forwardMessageUseCaseProvider);
    await _runBulk(
      label: 'Forwarding',
      total: ordered.length,
      action: (index) async {
        final message = ordered[index];
        final result = await useCase.execute(
          sourceChatId: message.chatId,
          sourceMessageId: message.id,
          targetChatId: targetChatId,
        );
        return result.match((failure) => failure.message, (_) => null);
      },
    );
  }

  Future<void> _deleteSelected() async {
    final state = ref.read(chatDetailProvider(widget.chatId)).value;
    final selected = _selectedMessageIds;
    if (state == null || selected == null || selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${selected.length} messages?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final ids = selected.toList();
    final notifier = ref.read(chatDetailProvider(widget.chatId).notifier);
    await _runBulk(
      label: 'Deleting',
      total: ids.length,
      action: (index) => notifier.deleteMessageReportingFailure(ids[index]),
    );
  }

  Future<void> _runBulk({
    required String label,
    required int total,
    required Future<String?> Function(int index) action,
  }) async {
    final progress = ValueNotifier<int>(0);
    final failures = <String>[];

    final dialog = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: ValueListenableBuilder<int>(
          valueListenable: progress,
          builder: (_, done, _) => Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(child: Text('$label $done of $total…')),
            ],
          ),
        ),
      ),
    );

    for (var index = 0; index < total; index++) {
      final failure = await action(index);
      if (failure != null) failures.add(failure);
      progress.value = index + 1;
    }

    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    progress.dispose();
    if (!mounted) return;

    _clearSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failures.isEmpty
              ? '$label complete ($total)'
              : '${total - failures.length} of $total succeeded — '
                    '${failures.length} failed: ${failures.first}',
        ),
      ),
    );
  }

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
      appBar: _selectionMode
          ? _buildSelectionAppBar(detail.value)
          : AppBar(
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
                      context.push(ChatMembersRoute.locationOf(widget.chatId)),
                ),
              ],
            ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: 'Failed to load chat',
          onRetry: () =>
              ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) {
          final me = state.me;
          final canSend = canSendMessage(state.chat, me);

          return Column(
            children: [
              const _ConnectionBanner(),
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
                    selectionMode: _selectionMode,
                    selectedIds: _selectedMessageIds ?? const <String>{},
                    onStartSelection: _startSelection,
                    onToggleSelected: _toggleSelected,
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
    final attachments = ref.read(chatAttachmentProvider(widget.chatId)).value;

    if (text.isEmpty && !(attachments?.isReady ?? false)) return;

    _textController.clear();

    await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .sendMessage(
          content: text.isEmpty ? null : text,
          uploadTokens: attachments?.uploadTokens ?? const [],
        );

    final spent = attachments?.uploadTokens ?? const <String>[];
    if (spent.isNotEmpty) {
      ref.read(confirmedAttachmentTokensProvider.notifier).release(spent);
    }

    ref.read(chatAttachmentProvider(widget.chatId).notifier).clear();
  }

  Future<void> _pickAttachments() async {
    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photos & videos'),
              subtitle: Text(
                'Up to ${ChatAttachmentLimits.maxMediaCount}, '
                '${ChatAttachmentLimits.formatBytes(ChatAttachmentLimits.maxMediaSizeBytes)} each',
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AttachmentSource.media),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: const Text('Document'),
              subtitle: Text(
                'One file, up to '
                '${ChatAttachmentLimits.formatBytes(ChatAttachmentLimits.maxFileSizeBytes)}',
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_AttachmentSource.document),
            ),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    final uploads = switch (source) {
      _AttachmentSource.media => await _pickMedia(),
      _AttachmentSource.document => await _pickDocument(),
    };

    if (uploads.isEmpty || !mounted) return;

    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);
    notifier.select(uploads);

    final selection = ref.read(chatAttachmentProvider(widget.chatId)).value;
    if (selection?.hasSelection ?? false) {
      await notifier.upload();
    }
  }

  Future<List<AttachmentUploadRequestEntity>> _pickMedia() async {
    final files = await ImagePicker().pickMultiImage();

    final uploads = <AttachmentUploadRequestEntity>[];
    for (final file in files) {
      uploads.add(
        AttachmentUploadRequestEntity(
          filename: file.name,
          mimeType: file.mimeType ?? _mimeFromName(file.name),
          fileSize: await file.length(),
          filePath: file.path,
        ),
      );
    }
    return uploads;
  }

  Future<List<AttachmentUploadRequestEntity>> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ChatAttachmentLimits.fileExtensions,
      allowMultiple: false,
      withData: kIsWeb,
      withReadStream: false,
    );

    final picked = result?.files.singleOrNull;
    if (picked == null) return const [];

    return [
      AttachmentUploadRequestEntity(
        filename: picked.name,
        mimeType: _mimeFromName(picked.name),
        fileSize: picked.size,
        filePath: kIsWeb ? null : picked.path,
        bytes: picked.bytes,
      ),
    ];
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
      case 'webm':
        return 'video/webm';
      case 'pdf':
        return 'application/pdf';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _joinCall() async {
    final result = await ref
        .read(joinCallUseCaseProvider)
        .execute(widget.chatId);
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
    required this.selectionMode,
    required this.selectedIds,
    required this.onStartSelection,
    required this.onToggleSelected,
  });

  final ChatDetailState state;
  final int? myUserId;
  final ScrollController scrollController;
  final String chatId;

  final bool selectionMode;
  final Set<String> selectedIds;
  final void Function(String messageId) onStartSelection;
  final void Function(String messageId) onToggleSelected;

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
          return const AppLoadMoreIndicator();
        }

        final message = state.messages[messageIndex];
        final notifier = ref.read(chatDetailProvider(chatId).notifier);
        final me = state.me;
        final isMine = myUserId != null && message.authorId == myUserId;

        return MessageBubble(
          message: message,
          isMine: isMine,
          selectionMode: selectionMode,
          isSelected: selectedIds.contains(message.id),
          onSelectionToggled: () => onToggleSelected(message.id),
          onStartSelection: () => onStartSelection(message.id),
          reactions: state.reactionsFor(message.id),
          onToggleReaction: (emoji) =>
              notifier.toggleReaction(message.id, emoji),
          onShowReactionUsers: (emoji) =>
              _showReactionUsers(context, ref, message.id, emoji),
          showReadTicks: isMine && state.chat?.type == ChatType.direct,
          readByPeer: state.isReadByPeer(message),
          onReply: canSendMessage(state.chat, me)
              ? () => notifier.setReplyTo(message)
              : null,
          onForward: () => _forward(context, ref, message),
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

  void _showReactionUsers(
    BuildContext context,
    WidgetRef ref,
    String messageId,
    String emoji,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _ReactionUsersSheet(
        chatId: chatId,
        messageId: messageId,
        emoji: emoji,
        members: state.chat?.members ?? const [],
      ),
    );
  }

  Future<void> _forward(
    BuildContext context,
    WidgetRef ref,
    MessageEntity message,
  ) async {
    final targetChatId = await showDialog<String>(
      context: context,
      builder: (dialogContext) =>
          _ForwardTargetDialog(excludeChatId: message.chatId),
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
          border: failed ? Border.all(color: theme.colorScheme.error) : null,
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

class _ConnectionBanner extends ConsumerWidget {
  const _ConnectionBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(chatSocketStatusProvider).value ??
        ref.read(chatSocketServiceProvider).status;

    final theme = Theme.of(context);

    final (String message, Color background, bool spinner) = switch (status) {
      ChatSocketStatus.ready ||
      ChatSocketStatus.connecting => ('', Colors.transparent, false),

      ChatSocketStatus.reconnecting => (
        'Reconnecting…',
        theme.colorScheme.secondaryContainer,
        true,
      ),

      ChatSocketStatus.disconnected => (
        'Offline — pull to refresh',
        theme.colorScheme.errorContainer,
        false,
      ),
    };

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: message.isEmpty
          ? const SizedBox(width: double.infinity, height: 0)
          : Container(
              width: double.infinity,
              color: background,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (spinner)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 14,
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall,
                    semanticsLabel: message,
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

class _AttachmentBar extends ConsumerWidget {
  const _AttachmentBar({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chatAttachmentProvider(chatId)).value;
    final theme = Theme.of(context);

    if (state == null) return const SizedBox.shrink();

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

    ref.watch(confirmedAttachmentTokensProvider);
    final confirmed = ref
        .read(confirmedAttachmentTokensProvider.notifier)
        .areReady(state.uploadTokens);

    final processing = state.uploadTokens.isNotEmpty && !confirmed;

    final String status;
    if (state.isUploading) {
      status = '';
    } else if (processing) {
      status = ' — processing…';
    } else if (state.isReady) {
      status = ' — ready to send';
    } else {
      status = '';
    }

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
                  '$status',
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
              child: LinearProgressIndicator(value: state.progress?.fraction),
            )
          else if (processing)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 2),
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
            IconButton(
              tooltip: 'Voice messages are not available yet',
              icon: const Icon(Icons.mic_none_outlined),
              onPressed: null,
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

class _ReactionUsersSheet extends ConsumerStatefulWidget {
  const _ReactionUsersSheet({
    required this.chatId,
    required this.messageId,
    required this.emoji,
    required this.members,
  });

  final String chatId;
  final String messageId;
  final String emoji;

  final List<ChatMemberEntity> members;

  @override
  ConsumerState<_ReactionUsersSheet> createState() =>
      _ReactionUsersSheetState();
}

class _ReactionUsersSheetState extends ConsumerState<_ReactionUsersSheet> {
  final _users = <int>[];

  bool _isLoading = true;
  bool _hasNext = false;
  int? _nextUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref
        .read(getReactionsUseCaseProvider)
        .executeUsers(
          widget.chatId,
          widget.messageId,
          emoji: widget.emoji,
          cursorUserId: _nextUserId,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      result.match((failure) => _error = failure.message, (page) {
        _users.addAll(page.users);
        _hasNext = page.hasNext;
        _nextUserId = page.nextUserId;
      });
    });
  }

  String _label(int userId) {
    for (final member in widget.members) {
      if (member.userId == userId) return member.displayLabel;
    }
    return 'User #$userId';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.emoji, style: theme.textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text('Reacted', style: theme.textTheme.titleMedium),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null && _users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_isLoading && _users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('Nobody has reacted with this yet')),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _users.length + (_hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          return _isLoading
              ? const AppLoadMoreIndicator()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: TextButton(
                      onPressed: _load,
                      child: const Text('Show more'),
                    ),
                  ),
                );
        }

        final userId = _users[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(_label(userId)),
          trailing: Text(widget.emoji, style: theme.textTheme.titleMedium),
        );
      },
    );
  }
}
