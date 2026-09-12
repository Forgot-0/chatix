import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/in_chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_attachment_picker.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_banners.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header.dart';
import 'package:chatix/features/chat/presentation/widgets/forward_target_dialog.dart';
import 'package:chatix/features/chat/presentation/widgets/in_chat_search_bar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One conversation.
///
/// The screen itself owns only what spans the whole chat: which message is
/// being edited, what is selected, whether the header has turned into a
/// search field. The conversation, the composer, the header and the banners
/// are each their own widget, and the feed owns everything tied to its own
/// scroll position.
class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.focusMessageId,
    this.focusMessageSeq,
  });

  final String chatId;

  /// Message to open on, named by id — what a push notification carries.
  final String? focusMessageId;

  /// Message to open on, named by its per-chat sequence number: the deep-link
  /// form `/chats/{id}?message={seq}`. Takes precedence over
  /// [focusMessageId], since it needs no lookup to resolve.
  final int? focusMessageSeq;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _textController = TextEditingController();
  final _searchController = TextEditingController();

  Set<String>? _selectedMessageIds;

  bool get _selectionMode => _selectedMessageIds != null;

  /// The search field in place of the header. Its own mode rather than a
  /// route: the messages stay on screen behind it, which is the whole point
  /// of searching inside one chat.
  bool _searchMode = false;

  bool _hasText = false;

  MessageEntity? _editing;

  String? _pendingFocusId;
  int? _pendingFocusSeq;

  @override
  void initState() {
    super.initState();

    // Whatever was typed here last time and never sent. Restored before the
    // listener goes on, so putting it back does not count as a fresh edit.
    _textController.text =
        ref.read(chatDraftsProvider.notifier).of(widget.chatId) ?? '';
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _hasText = _textController.text.trim().isNotEmpty;

    _textController.addListener(_onTextChanged);

    _pendingFocusId = widget.focusMessageId;
    _pendingFocusSeq = widget.focusMessageSeq;
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(chatDetailProvider(widget.chatId));
    final myUserId = ref.watch(authProvider).value?.id;

    final pendingFocusId = _pendingFocusId;
    final pendingFocusSeq = _pendingFocusSeq;
    if ((pendingFocusId != null || pendingFocusSeq != null) &&
        detail.hasValue) {
      _pendingFocusId = null;
      _pendingFocusSeq = null;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusOnOpen(messageId: pendingFocusId, seq: pendingFocusSeq),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(detail.value, myUserId),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: AppLocalizations.of(context).chatLoadFailed,
          onRetry: () =>
              ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) => _buildBody(state, myUserId),
      ),
    );
  }

  Widget _buildBody(ChatDetailState state, int? myUserId) {
    final me = state.me;
    final canSend = canSendMessage(state.chat, me);

    return Column(
      children: [
        const ChatConnectionBanner(),
        if (state.isRealtimeRejected) const ChatRealtimeRejectedBanner(),
        Expanded(
          child: ChatFeed(
            chatId: widget.chatId,
            state: state,
            myUserId: myUserId,
            selectionMode: _selectionMode,
            selectedIds: _selectedMessageIds ?? const <String>{},
            onStartSelection: _startSelection,
            onToggleSelected: _toggleSelected,
            onEdit: _startEditing,
            onRefresh: () =>
                ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
          ),
        ),
        if (state.isViewingHistory)
          ChatBackToLatestBar(
            onPressed: () => ref
                .read(chatDetailProvider(widget.chatId).notifier)
                .returnToLatest(),
          ),
        if (_editing != null)
          ChatEditBanner(message: _editing!, onCancel: _cancelEditing)
        else if (state.replyTo != null)
          ChatReplyBanner(
            message: state.replyTo!,
            onCancel: () => ref
                .read(chatDetailProvider(widget.chatId).notifier)
                .setReplyTo(null),
          ),
        ChatAttachmentBar(chatId: widget.chatId),
        ChatComposer(
          controller: _textController,
          enabled: canSend,
          isEditing: _editing != null,
          hasText: _hasText,
          isRecording: ref.watch(voiceRecordProvider).isRecording,
          disabledReason: _disabledReason(state.chat, me),
          onAttach: canSend && _editing == null ? _pickAttachments : null,
          onSend: canSend ? _send : null,
          onVoiceRecorded: canSend ? _sendVoice : null,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- app bars

  PreferredSizeWidget _buildAppBar(ChatDetailState? state, int? myUserId) {
    if (_selectionMode) return _buildSelectionAppBar(state);
    if (_searchMode) return _buildSearchAppBar();

    final l10n = AppLocalizations.of(context);

    return AppBar(
      // In two-pane mode the list stays on screen beside the chat, so there
      // is nothing for a back arrow to reveal.
      automaticallyImplyLeading: !AppLayoutScope.of(context).isTwoPane,
      titleSpacing: 0,
      title: ChatHeaderTitle(
        chatId: widget.chatId,
        chat: state?.chat,
        myUserId: myUserId,
        onTap: state?.chat == null
            ? null
            : () => context.push(ChatInfoRoute.locationOf(widget.chatId)),
      ),
      actions: [
        IconButton(
          tooltip: l10n.searchInChat,
          icon: const Icon(Icons.search),
          onPressed: () => _setSearchMode(on: true),
        ),
        IconButton(
          tooltip: l10n.callTitle,
          icon: const Icon(Icons.call_outlined),
          onPressed: state?.chat == null
              ? null
              : () => context.push(ChatCallRoute.locationOf(widget.chatId)),
        ),
        IconButton(
          tooltip: l10n.membersTitle,
          icon: const Icon(Icons.people_outline),
          onPressed: () =>
              context.push(ChatMembersRoute.locationOf(widget.chatId)),
        ),
      ],
    );
  }

  /// Turns the header into a search field, and back.
  ///
  /// Leaving drops the matches: a search you cannot see the field for is a
  /// chat that scrolls to places you did not ask for.
  void _setSearchMode({required bool on}) {
    if (_searchMode == on) return;

    if (!on) {
      _searchController.clear();
      ref.read(inChatSearchProvider(widget.chatId).notifier).clear();
    }

    setState(() => _searchMode = on);
  }

  PreferredSizeWidget _buildSearchAppBar() {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(inChatSearchProvider(widget.chatId).notifier);

    return AppBar(
      leading: IconButton(
        tooltip: l10n.close,
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _setSearchMode(on: false),
      ),
      titleSpacing: 0,
      title: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: controller.type,
        onSubmitted: controller.submit,
        decoration: InputDecoration(
          hintText: l10n.searchInChatHint,
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            tooltip: l10n.clear,
            icon: const Icon(Icons.close),
            onPressed: () {
              _searchController.clear();
              controller.clear();
              setState(() {});
            },
          ),
      ],
      bottom: InChatSearchBar(chatId: widget.chatId),
    );
  }

  PreferredSizeWidget _buildSelectionAppBar(ChatDetailState? state) {
    final l10n = AppLocalizations.of(context);
    final selected = _selectedMessageIds ?? const <String>{};
    final canDelete =
        state != null &&
        selected.isNotEmpty &&
        selected.every((id) {
          final message = _findMessage(state, id);
          return message != null &&
              canDeleteMessage(state.chat, state.me, message.authorId);
        });

    final canCopy =
        state != null &&
        selected.any((id) {
          final message = _findMessage(state, id);
          return message?.content?.trim().isNotEmpty ?? false;
        });

    return AppBar(
      leading: IconButton(
        tooltip: l10n.cancel,
        icon: const Icon(Icons.close),
        onPressed: _clearSelection,
      ),
      title: Text(l10n.selectedCount(selected.length)),
      actions: [
        IconButton(
          tooltip: l10n.messageCopy,
          icon: const Icon(Icons.copy_all_outlined),
          onPressed: canCopy ? _copySelected : null,
        ),
        IconButton(
          tooltip: l10n.messageForward,
          icon: const Icon(Icons.shortcut),
          onPressed: selected.isEmpty ? null : _forwardSelected,
        ),
        IconButton(
          tooltip: l10n.messageDelete,
          icon: const Icon(Icons.delete_outline),
          onPressed: canDelete ? _deleteSelected : null,
        ),
      ],
    );
  }

  // --------------------------------------------------------------- selection

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

    final target = await ForwardTargetDialog.pick(
      context,
      excludeChatId: widget.chatId,
    );
    if (target == null || !mounted) return;

    final ordered = state.messages
        .where((message) => selected.contains(message.id))
        .toList()
        .reversed
        .toList();

    final useCase = ref.read(forwardMessageUseCaseProvider);
    await _runBulk(
      label: AppLocalizations.of(context).bulkForwarding,
      total: ordered.length,
      action: (index) async {
        final message = ordered[index];
        final result = await useCase.execute(
          sourceChatId: message.chatId,
          sourceMessageId: message.id,
          targetChatId: target.chatId,
          // The comment rides along with the first message only: repeating it
          // on every item of a bulk forward would spam the target chat.
          comment: index == 0 ? target.comment : null,
        );
        return result.match((failure) => failure.message, (_) => null);
      },
    );
  }

  /// Puts every selected message's text on the clipboard, oldest first.
  ///
  /// Messages with nothing but an attachment contribute nothing: there is no
  /// text to paste, and a line saying so would be text nobody wrote.
  void _copySelected() {
    final state = ref.read(chatDetailProvider(widget.chatId)).value;
    final selected = _selectedMessageIds;
    if (state == null || selected == null || selected.isEmpty) return;

    final lines = [
      for (final message in state.messages.reversed)
        if (selected.contains(message.id))
          if (message.content?.trim().isNotEmpty ?? false) message.content!,
    ];
    if (lines.isEmpty) return;

    Clipboard.setData(ClipboardData(text: lines.join('\n')));
    _clearSelection();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).messageCopied)),
    );
  }

  Future<void> _deleteSelected() async {
    final state = ref.read(chatDetailProvider(widget.chatId)).value;
    final selected = _selectedMessageIds;
    if (state == null || selected == null || selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext);

        return AlertDialog(
          title: Text(l10n.deleteMessagesTitle(selected.length)),
          content: Text(l10n.cannotBeUndone),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.messageDelete),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    final ids = selected.toList();
    final notifier = ref.read(chatDetailProvider(widget.chatId).notifier);
    await _runBulk(
      label: AppLocalizations.of(context).bulkDeleting,
      total: ids.length,
      action: (index) => notifier.deleteMessageReportingFailure(ids[index]),
    );
  }

  Future<void> _runBulk({
    required String label,
    required int total,
    required Future<String?> Function(int index) action,
  }) async {
    final l10n = AppLocalizations.of(context);
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
              Expanded(child: Text(l10n.bulkProgress(label, done, total))),
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
              ? l10n.bulkComplete(label, total)
              : l10n.bulkPartial(
                  total - failures.length,
                  total,
                  failures.length,
                  failures.first,
                ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------- jump to one

  Future<void> _focusOnOpen({String? messageId, int? seq}) async {
    final notifier = ref.read(chatDetailProvider(widget.chatId).notifier);

    final ok = seq != null
        ? await notifier.revealSeq(seq)
        : await notifier.revealMessage(messageId!);
    if (ok || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).messageNotFound)),
    );
  }

  // ---------------------------------------------------------------- composer

  void _startEditing(MessageEntity message) {
    setState(() => _editing = message);
    _textController.text = message.content ?? '';
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  void _cancelEditing() {
    setState(() => _editing = null);

    // Back to the draft the edit interrupted, so the composer and the chat
    // row agree about what is waiting to be sent.
    _textController.text =
        ref.read(chatDraftsProvider.notifier).of(widget.chatId) ?? '';
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
  }

  void _onTextChanged() {
    final has = _textController.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);

    // While an edit is in the composer the text belongs to that message, not
    // to a draft of the next one.
    if (_editing == null) {
      ref
          .read(chatDraftsProvider.notifier)
          .save(widget.chatId, _textController.text);
    }
  }

  String _disabledReason(ChatEntity? chat, ChatMemberEntity? me) {
    final l10n = AppLocalizations.of(context);

    if (me == null) return l10n.composerJoinToSend;
    if (me.isBanned) return l10n.composerBanned;
    if (me.isMuted) return l10n.composerMuted;
    if (chat?.adminOnly == true) return l10n.composerAdminsOnly;
    return l10n.composerNoPermission;
  }

  Future<void> _send() async {
    final editing = _editing;
    if (editing != null) {
      final text = _textController.text.trim();
      if (text.isEmpty || text == (editing.content ?? '')) {
        _cancelEditing();
        return;
      }

      _cancelEditing();
      try {
        await ref
            .read(chatDetailProvider(widget.chatId).notifier)
            .editMessage(editing.id, text);
      } on Failure catch (failure) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
      return;
    }

    final text = _textController.text.trim();
    final attachments = ref.read(chatAttachmentProvider(widget.chatId)).value;

    if (text.isEmpty && !(attachments?.isReady ?? false)) return;

    _textController.clear();
    ref.read(chatDraftsProvider.notifier).clear(widget.chatId);

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

  Future<void> _sendVoice(VoiceRecording recording) async {
    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);

    notifier.select([
      AttachmentUploadRequestEntity.voice(
        filename: recording.path.split('/').last,
        mimeType: recording.mimeType,
        fileSize: recording.sizeBytes,
        filePath: recording.path,
      ),
    ]);

    final selection = ref.read(chatAttachmentProvider(widget.chatId)).value;
    if (selection?.failure != null) return;

    await notifier.upload();
    if (!mounted) return;

    final uploaded = ref.read(chatAttachmentProvider(widget.chatId)).value;
    final tokens = uploaded?.uploadTokens ?? const <String>[];
    if (tokens.isEmpty) return;

    await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .sendMessage(uploadTokens: tokens, messageType: MessageType.voice);

    ref.read(confirmedAttachmentTokensProvider.notifier).release(tokens);
    notifier.clear();
  }

  Future<void> _pickAttachments() async {
    final uploads = await ChatAttachmentPicker.pick(context);
    if (uploads.isEmpty || !mounted) return;

    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);
    notifier.select(uploads);

    final selection = ref.read(chatAttachmentProvider(widget.chatId)).value;
    if (selection?.hasSelection ?? false) {
      await notifier.upload();
    }
  }
}
