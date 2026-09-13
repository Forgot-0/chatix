import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/in_chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';
import 'package:chatix/features/chat/presentation/providers/reaction_notice_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/features/chat/presentation/screens/media_preview_screen.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/reaction_notice_text.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_banners.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_attachment_sheet.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_attachment_tray.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_locked_notice.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/video_note_sheet.dart';
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
  final _composerFocus = FocusNode();
  final _searchController = TextEditingController();

  Set<String>? _selectedMessageIds;

  bool get _selectionMode => _selectedMessageIds != null;

  /// The search field in place of the header. Its own mode rather than a
  /// route: the messages stay on screen behind it, which is the whole point
  /// of searching inside one chat.
  bool _searchMode = false;

  String? _pendingFocusId;
  int? _pendingFocusSeq;

  ComposerController get _composer =>
      ref.read(composerProvider(widget.chatId).notifier);

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

    _textController.addListener(_onTextChanged);

    // The draft restored above is what the counter and the send button have
    // to agree with before the first keystroke.
    final restored = _textController.text.length;
    if (restored > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _composer.setLength(restored);
      });
    }

    _pendingFocusId = widget.focusMessageId;
    _pendingFocusSeq = widget.focusMessageSeq;
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);

    // Whatever is in the box goes to disk now rather than on the debounce:
    // the screen is about to be gone, and a draft that only exists in memory
    // is a draft the chat list will not show (api-docs has nowhere to put
    // one, so this device is the only place it lives).
    unawaited(ref.read(chatDraftsProvider.notifier).flush());

    _textController.dispose();
    _composerFocus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(chatDetailProvider(widget.chatId));
    final myUserId = ref.watch(authProvider).value?.id;

    // A reaction that the server refused has already been taken back off the
    // message by the time this fires; all that is left is to say so, quietly.
    ref.listen(reactionNoticeProvider, (previous, next) {
      if (next == null || next == previous) return;
      AppSnackbar.quiet(
        context,
        reactionNoticeText(AppLocalizations.of(context), next.reason),
      );
    });

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
    final lockedBecause = ComposerLockedNotice.reasonFor(state.chat, me);

    // Slow mode is re-read from the chat on every build, so a `chat_updated`
    // that switches it on or off reaches the send button without a reload
    // (api-docs §5.2, §6.4).
    final interval = slowModeInterval(state.chat, me);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composer.syncSlowMode(interval);
    });

    final composer = ref.watch(composerProvider(widget.chatId));
    final attachments = ref.watch(chatAttachmentProvider(widget.chatId)).value;

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
        if (lockedBecause != null)
          ComposerLockedNotice(reason: lockedBecause)
        else ...[
          ComposerAttachmentTray(chatId: widget.chatId),
          ChatComposer(
            controller: _textController,
            focusNode: _composerFocus,
            length: composer.length,
            hasAttachments: attachments?.isReady ?? false,
            isRecording: ref.watch(voiceRecordProvider).isRecording,
            slowMode: composer.slowMode,
            isSending: composer.isSending,
            replyTo: state.replyTo,
            editing: composer.editing,
            onCancelContext: _cancelComposerContext,
            // An edit gains no attachments: `PATCH .../messages/{id}/` only
            // carries `content` (api-docs §5.4).
            onAttach: composer.isEditing ? null : _openAttachmentSheet,
            onSend: _send,
            onVoiceRecorded: composer.isEditing ? null : _sendVoice,
          ),
        ],
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
    _composer.startEditing(message);
    _setText(message.content ?? '');
    _composerFocus.requestFocus();
  }

  /// Drops whatever the banner is showing — the edit if there is one, the
  /// reply otherwise. One gesture, because the banner is one strip.
  void _cancelComposerContext() {
    if (ref.read(composerProvider(widget.chatId)).isEditing) {
      _cancelEditing();
      return;
    }
    ref.read(chatDetailProvider(widget.chatId).notifier).setReplyTo(null);
  }

  void _cancelEditing() {
    _composer.cancelEditing();

    // Back to the draft the edit interrupted, so the composer and the chat
    // row agree about what is waiting to be sent.
    _setText(ref.read(chatDraftsProvider.notifier).of(widget.chatId) ?? '');
  }

  void _setText(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _composer.setLength(text.length);
  }

  void _onTextChanged() {
    final text = _textController.text;
    _composer.setLength(text.length);

    // While an edit is in the composer the text belongs to that message, not
    // to a draft of the next one.
    if (!ref.read(composerProvider(widget.chatId)).isEditing) {
      ref.read(chatDraftsProvider.notifier).save(widget.chatId, text);
    }
  }

  Future<void> _send() async {
    final composer = ref.read(composerProvider(widget.chatId));

    // The clock is checked here as well as drawn on the button: a tap that
    // lands in the same frame the countdown ends would otherwise go out and
    // come back 429.
    if (composer.slowMode.isWaitingAt(DateTime.now())) return;
    if (composer.isSending) return;

    final editing = composer.editing;
    if (editing != null) {
      await _commitEdit(editing);
      return;
    }

    final text = _textController.text.trim();
    if (MessageLimits.isOverLimit(text.length)) return;

    final attachments = ref.read(chatAttachmentProvider(widget.chatId)).value;
    if (text.isEmpty && !(attachments?.isReady ?? false)) return;

    _setText('');
    ref.read(chatDraftsProvider.notifier).clear(widget.chatId);

    // Optimistic, like the pending bubble it puts on screen: the wait starts
    // now and a 429 replaces it with the server's own `retry_after`.
    _composer.markSent();
    _composer.setSending(value: true);

    await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .sendMessage(
          content: text.isEmpty ? null : text,
          uploadTokens: attachments?.uploadTokens ?? const [],
        );

    if (!mounted) return;
    _composer.setSending(value: false);

    final spent = attachments?.uploadTokens ?? const <String>[];
    if (spent.isNotEmpty) {
      ref.read(confirmedAttachmentTokensProvider.notifier).release(spent);
    }

    ref.read(chatAttachmentProvider(widget.chatId).notifier).clear();
  }

  Future<void> _commitEdit(MessageEntity editing) async {
    final text = _textController.text.trim();

    if (text.isEmpty ||
        text == (editing.content ?? '') ||
        MessageLimits.isOverLimit(text.length)) {
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
  }

  Future<void> _sendVoice(VoiceRecording recording) async {
    await _sendExclusive(
      AttachmentUploadRequestEntity.voice(
        filename: recording.path.split('/').last,
        mimeType: recording.mimeType,
        fileSize: recording.sizeBytes,
        filePath: recording.path,
      ),
      MessageType.voice,
    );
  }

  /// Uploads one attachment that travels alone and sends it on its own.
  ///
  /// `voice` and `video_note` cannot be mixed with anything, including each
  /// other (api-docs §5.5), so they never join whatever is staged — they
  /// replace it and go straight out.
  Future<void> _sendExclusive(
    AttachmentUploadRequestEntity upload,
    MessageType type,
  ) async {
    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);

    notifier.select([upload]);
    if (ref.read(chatAttachmentProvider(widget.chatId)).value?.failure !=
        null) {
      return;
    }

    await notifier.upload();
    if (!mounted) return;

    final tokens =
        ref.read(chatAttachmentProvider(widget.chatId)).value?.uploadTokens ??
        const <String>[];
    if (tokens.isEmpty) return;

    _composer.markSent();

    await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .sendMessage(uploadTokens: tokens, messageType: type);

    ref.read(confirmedAttachmentTokensProvider.notifier).release(tokens);
    notifier.clear();
  }

  // ------------------------------------------------------------- attachments

  Future<void> _openAttachmentSheet() async {
    final result = await ComposerAttachmentSheet.show(context);
    if (result == null || !mounted) return;

    switch (result.kind) {
      case ComposerAttachmentKind.uploads:
        await _stageUploads(result.uploads);
      case ComposerAttachmentKind.recordVoice:
        // The same hands-free recording the send button's lock gesture
        // reaches, started from the menu instead of by dragging.
        await ref.read(voiceRecordProvider.notifier).start();
        ref.read(voiceRecordProvider.notifier).lock();
      case ComposerAttachmentKind.recordVideoNote:
        await _captureVideoNote();
    }
  }

  /// Takes what was picked and decides what happens to it next.
  ///
  /// Photos and videos go through the preview screen first: an album is
  /// worth looking at before it is sent, something picked by accident is
  /// worth dropping, and the caption typed there becomes the message's
  /// `content` (api-docs §5.4). A document has nothing to arrange — one
  /// file, no caption of its own — so it is simply staged.
  Future<void> _stageUploads(
    List<AttachmentUploadRequestEntity> uploads,
  ) async {
    if (uploads.isEmpty) return;

    final isAlbum = uploads.every((upload) {
      final type = upload.resolvedType;
      return type == AttachmentType.image || type == AttachmentType.video;
    });

    if (!isAlbum) {
      await _stageAndUpload(uploads);
      return;
    }

    final draft = _textController.text.trim();
    final result = await context.push<MediaPreviewResult>(
      ChatAttachRoute.locationOf(widget.chatId),
      extra: MediaPreviewArgs(
        uploads: uploads,
        caption: draft.isEmpty ? null : draft,
      ),
    );

    if (!mounted || result == null || result.uploads.isEmpty) return;
    await _sendAlbum(result);
  }

  /// Stages files and starts their upload, leaving the send to the composer.
  Future<void> _stageAndUpload(
    List<AttachmentUploadRequestEntity> uploads,
  ) async {
    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);
    notifier.select(uploads);

    if (ref.read(chatAttachmentProvider(widget.chatId)).value?.hasSelection ??
        false) {
      await notifier.upload();
    }
  }

  /// Uploads an album and sends it with its caption.
  ///
  /// The send button in the preview means "send", so there is nothing left
  /// to press afterwards — the tray shows the upload, and the message goes
  /// out as soon as the slots are in hand. An upload that was cancelled or
  /// refused leaves no tokens and no message; the tray says which.
  Future<void> _sendAlbum(MediaPreviewResult result) async {
    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);
    notifier.select(result.uploads);

    if (ref.read(chatAttachmentProvider(widget.chatId)).value?.failure !=
        null) {
      return;
    }

    // The caption has left the box for the message.
    _setText('');
    ref.read(chatDraftsProvider.notifier).clear(widget.chatId);

    await notifier.upload();
    if (!mounted) return;

    final tokens =
        ref.read(chatAttachmentProvider(widget.chatId)).value?.uploadTokens ??
        const <String>[];

    if (tokens.isEmpty) {
      // Cancelled, or the upload gave up. The caption goes back in the box
      // so a second attempt from the tray still has it.
      final caption = result.caption;
      if (caption != null) _setText(caption);
      return;
    }

    _composer.markSent();
    _composer.setSending(value: true);

    await ref
        .read(chatDetailProvider(widget.chatId).notifier)
        .sendMessage(content: result.caption, uploadTokens: tokens);

    if (!mounted) return;
    _composer.setSending(value: false);

    ref.read(confirmedAttachmentTokensProvider.notifier).release(tokens);
    notifier.clear();
  }

  /// Records a video note and sends it.
  ///
  /// The recorder owns the camera rather than borrowing the system one: a
  /// `video_note` must come in under 640 px and 60 s (api-docs §5.5), and
  /// nothing downstream will resize it — so it is recorded at a size the
  /// server already accepts. A take that comes back empty was too short or
  /// unreadable, which is worth a word and nothing more.
  Future<void> _captureVideoNote() async {
    final take = await VideoNoteSheet.show(context);
    if (!mounted) return;

    if (take == null) return;

    await _sendExclusive(take.upload, MessageType.videoNote);
  }
}
