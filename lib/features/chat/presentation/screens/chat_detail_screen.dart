import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/settings/send_shortcut.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/haptics.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/data/datasources/clipboard_attachments.dart';
import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_attachment_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_drafts_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/providers/in_chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';
import 'package:chatix/features/chat/presentation/providers/reaction_notice_provider.dart';
import 'package:chatix/features/chat/presentation/providers/recent_emoji_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_record_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/features/chat/presentation/screens/media_preview_screen.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/utils/composer_text_edits.dart';
import 'package:chatix/features/chat/presentation/utils/mention_syntax.dart';
import 'package:chatix/features/chat/presentation/utils/message_editing.dart';
import 'package:chatix/features/chat/presentation/utils/reaction_notice_text.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_banners.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_drop_zone.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed_metrics.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed_skeleton.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_wallpaper.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_attachment_sheet.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_attachment_tray.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_locked_notice.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_panel_host.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/emoji_panel.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/mention_suggestions.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/video_note_sheet.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header.dart';
import 'package:chatix/features/chat/presentation/widgets/forward_target_dialog.dart';
import 'package:chatix/features/chat/presentation/widgets/in_chat_search_bar.dart';
import 'package:chatix/features/chat/presentation/widgets/message_delete_dialog.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/contacts/presentation/widgets/block_actions.dart';
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

  /// Keyboard, emoji panel, or neither — what sits under the composer.
  final _input = ComposerInputController();

  /// The `@query` the caret is in, in a chat where people can be mentioned.
  final _mention = ValueNotifier<MentionQuery?>(null);

  /// The suggestion the arrow keys are on, on a desktop.
  final _mentionHighlight = ValueNotifier<int>(0);

  /// A query put away with Esc stays away until the person types on.
  MentionQuery? _dismissedMention;

  /// Holds focus while messages are being picked, so Esc reaches the screen
  /// and not whatever had focus before — usually the composer, which the
  /// selection takes the keyboard away from anyway.
  final _screenFocus = FocusNode(debugLabel: 'ChatDetailScreen');

  Set<String>? _selectedMessageIds;

  bool get _selectionMode => _selectedMessageIds != null;

  /// The search field in place of the header. Its own mode rather than a
  /// route: the messages stay on screen behind it, which is the whole point
  /// of searching inside one chat.
  bool _searchMode = false;

  String? _pendingFocusId;
  int? _pendingFocusSeq;

  /// Taken in [initState] because [dispose] needs it, and `ref` is off
  /// limits there: Riverpod 3 throws a StateError for any use of it once the
  /// element is unmounting, which used to cost the draft and every
  /// controller below the throw.
  late final ChatDraftsController _drafts;

  ComposerController get _composer =>
      ref.read(composerProvider(widget.chatId).notifier);

  /// This chat's row in whichever chat list is alive — never starting one
  /// that is not, which for the archive would be a request nobody asked for.
  ChatEntity? _listedRow() {
    for (final list in [chatListProvider, archivedChatListProvider]) {
      if (!ref.exists(list)) continue;
      final row = ref.read(list.notifier).rowOf(widget.chatId);
      if (row != null) return row;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    _drafts = ref.read(chatDraftsProvider.notifier);

    // The list row carries the server's copy of the draft — possibly typed
    // on another device, and newer than this one's. Whichever is newer is
    // the one to open on.
    final listed = _listedRow();
    if (listed != null) _drafts.reconcile([listed]);

    // Whatever was typed here last time and never sent. Restored before the
    // listener goes on, so putting it back does not count as a fresh edit.
    _textController.text = _drafts.of(widget.chatId) ?? '';
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

    // Whatever this chat put in the shade is answered by being here; leaving
    // it there would have the reader dismiss the same messages twice.
    unawaited(
      ref
          .read(notificationServiceProvider)
          .cancelGroup('chat_${widget.chatId}'),
    );
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);

    // Whatever is in the box goes to disk and to the server now rather than
    // on the debounce: the screen is about to be gone, and a draft that only
    // exists in memory is a draft neither the list nor another device shows.
    unawaited(_drafts.flush());

    _textController.dispose();
    _composerFocus.dispose();
    _input.dispose();
    _mention.dispose();
    _mentionHighlight.dispose();
    _searchController.dispose();
    _screenFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(chatDetailProvider(widget.chatId));
    final myUserId = ref.watch(authProvider).value?.id;

    // The chat profile has a search button of its own, and the field it
    // means is this one. It names the chat and comes back here; opening the
    // field is this screen's to do.
    ref.listen(chatSearchRequestProvider, (previous, next) {
      if (next != widget.chatId) return;
      ref.read(chatSearchRequestProvider.notifier).clear();
      _setSearchMode(on: true);
    });

    // A reaction that the server refused has already been taken back off the
    // message by the time this fires; all that is left is to say so, quietly.
    ref.listen(reactionNoticeProvider, (previous, next) {
      if (next == null || next == previous) return;
      AppSnackbar.failure(
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

    // Back and Esc step out of a mode before they step out of the chat: a
    // selection or a search is a state of this screen, not a page on the
    // stack, and losing the whole chat to undo either is the wrong size of
    // answer.
    final inMode = _selectionMode || _searchMode;

    // The emoji panel is the innermost of these: back puts it away first,
    // the way it would the keyboard it stands in for.
    return ListenableBuilder(
      listenable: _input,
      builder: (context, child) {
        final panelOpen = _input.showsPanel;

        return PopScope(
          canPop: !inMode && !panelOpen,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (panelOpen) {
              _closeEmojiPanel();
              return;
            }
            _leaveMode();
          },
          child: CallbackShortcuts(
            bindings: {
              // On a desktop Esc always means something here — with nothing
              // else open it closes the chat — so it is always bound. On a
              // phone it only ever steps out of a mode, as back does.
              if (DesktopInput.isDesktop)
                const SingleActivator(LogicalKeyboardKey.escape): _onEscape
              else if (panelOpen)
                const SingleActivator(LogicalKeyboardKey.escape):
                    _closeEmojiPanel
              else if (inMode)
                const SingleActivator(LogicalKeyboardKey.escape): _leaveMode,
            },
            child: child!,
          ),
        );
      },
      child: Focus(
        focusNode: _screenFocus,
        child: _buildScaffold(detail, myUserId),
      ),
    );
  }

  Widget _buildScaffold(AsyncValue<ChatDetailState> detail, int? myUserId) {
    return Scaffold(
      // The keyboard is made room for by [ComposerPanelHost] instead: a
      // scaffold can only shrink the body by it, and keeping the body still
      // while the keyboard and the emoji panel trade places is the point.
      resizeToAvoidBottomInset: false,
      appBar: _buildAppBar(detail.value, myUserId),
      body: detail.when(
        // The shape of the conversation, not a spinner: the bubbles land in
        // the space their placeholders were already holding — on the
        // wallpaper they will land on, so nothing under them changes either.
        loading: () => ChatWallpaper(
          seed: widget.chatId.hashCode,
          child: const ChatFeedSkeleton(),
        ),
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

    // A direct chat with somebody the reader blocked has no composer, only
    // the bar that says so and lifts it (api-docs §4.13: the server would
    // still take the message — this is the client's side of a block).
    final peerId = state.chat?.peerUserId(myUserId);
    final peerBlocked =
        peerId != null && ref.watch(isUserBlockedProvider(peerId));
    final lockedBecause = ComposerLockedNotice.reasonFor(
      state.chat,
      me,
      peerBlocked: peerBlocked,
    );

    // The panel belongs to a composer that is no longer there.
    if (lockedBecause != null && _input.isEmojiOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _input.isEmojiOpen) _closeEmojiPanel();
      });
    }

    // Files may be dropped wherever the paperclip would take them: not on a
    // locked chat, and not into an edit, which carries text only (api-docs
    // §5.4).
    final isEditing = ref.watch(
      composerProvider(widget.chatId).select((it) => it.isEditing),
    );

    // Slow mode is re-read from the chat on every build, so a `chat_updated`
    // that switches it on or off reaches the send button without a reload
    // (api-docs §5.2, §6.4).
    final interval = slowModeInterval(state.chat, me);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composer.syncSlowMode(interval);
    });

    final body = Column(
      children: [
        const ChatConnectionStrip(),
        if (state.isRealtimeRejected) const ChatRealtimeRejectedBanner(),
        ChatOngoingCallBanner(chatId: widget.chatId),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                // A tap on the conversation puts the emoji panel away, as
                // it would the keyboard. Only a tap nothing in the feed
                // claimed: a bubble's own tap still wins.
                child: ListenableBuilder(
                  listenable: _input,
                  builder: (context, child) => GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _input.isEmojiOpen ? _closeEmojiPanel : null,
                    child: child,
                  ),
                  child: ChatFeed(
                    chatId: widget.chatId,
                    state: state,
                    myUserId: myUserId,
                    selectionMode: _selectionMode,
                    selectedIds: _selectedMessageIds ?? const <String>{},
                    onStartSelection: _startSelection,
                    onToggleSelected: _toggleSelected,
                    onEdit: _startEditing,
                    onDelete: (messageId) =>
                        unawaited(_deleteMessages([messageId])),
                    onRefresh: () => ref
                        .read(chatDetailProvider(widget.chatId).notifier)
                        .refresh(),
                  ),
                ),
              ),
              // Over the bottom of the feed rather than in the column: the
              // list comes and goes with each keystroke, and the messages
              // should not bounce with it.
              Positioned(
                left: 0,
                right: 0,
                // One pixel past the edge: the list's bottom border is
                // clipped, and the composer's top line is the only one.
                bottom: -1,
                child: _buildMentionSuggestions(state, myUserId),
              ),
            ],
          ),
        ),
        if (state.isViewingHistory)
          ChatBackToLatestBar(
            onPressed: () => ref
                .read(chatDetailProvider(widget.chatId).notifier)
                .returnToLatest(),
          ),
        if (lockedBecause != null)
          ComposerLockedNotice(
            reason: lockedBecause,
            action:
                lockedBecause == ComposerLockReason.blockedPeer &&
                    peerId != null
                ? _UnblockPeerButton(chat: state.chat!, peerId: peerId)
                : null,
          )
        else ...[
          ComposerAttachmentTray(chatId: widget.chatId),
          // The physical keyboard's half of the composer — Enter, ↑, and a
          // paste that brings files — around the mention list's own keys
          // rather than inside them, so that while the list is up its Enter
          // picks a person instead of sending.
          _DesktopComposerKeys(
            onKey: _onComposerKey,
            onPaste: _pasteAttachments,
            // Its own consumer, and deliberately so: the composer's length,
            // its send state and the two recorders change on every
            // keystroke, and watching them up here would put the whole feed
            // — every visible bubble — in the rebuild scope of typing a
            // character.
            child: ValueListenableBuilder<MentionQuery?>(
              valueListenable: _mention,
              builder: (context, query, child) => CallbackShortcuts(
                bindings: _mentionShortcuts(state, myUserId, query),
                child: child!,
              ),
              child: _ComposerSection(
                chatId: widget.chatId,
                controller: _textController,
                focusNode: _composerFocus,
                input: _input,
                replyTo: state.replyTo,
                onCancelContext: _cancelComposerContext,
                onAttach: _openAttachmentSheet,
                onSend: _send,
                onVoiceRecorded: _sendVoice,
                onVideoNoteRecorded: _sendVideoNote,
                onToggleEmoji: _toggleEmojiPanel,
                onFieldTap: _onComposerFieldTap,
              ),
            ),
          ),
        ],
      ],
    );

    return ChatDropZone(
      enabled: lockedBecause == null && !isEditing,
      onDropped: _onFilesDropped,
      child: _buildPanelHost(body),
    );
  }

  Widget _buildPanelHost(Widget body) {
    return ComposerPanelHost(
      controller: _input,
      panelBuilder: (context, height, compact) => TextFieldTapRegion(
        child: EmojiPanel(
          // Read, not watched: the panel takes its "Recent" once, as it
          // opens, so the row does not reshuffle under the finger.
          recent: ref.read(recentEmojiProvider),
          compact: compact,
          onEmoji: _insertEmoji,
          onBackspace: _deleteBackwards,
          onSearchFocusChanged: (focused) =>
              _input.setSearching(value: focused),
        ),
      ),
      child: body,
    );
  }

  // ---------------------------------------------------------------- app bars

  PreferredSizeWidget _buildAppBar(ChatDetailState? state, int? myUserId) {
    if (_selectionMode) return _buildSelectionAppBar(state);
    if (_searchMode) return _buildSearchAppBar();

    final chat = state?.chat;

    return AppBar(
      // In two-pane mode the list stays on screen beside the chat, so there
      // is nothing for a back arrow to reveal.
      automaticallyImplyLeading: !AppLayoutScope.of(context).isTwoPane,
      titleSpacing: 0,
      // The profile is nested under the chat's own location, so in two-pane
      // mode it opens in the right pane and the list keeps this chat marked.
      title: ChatHeaderTitle(
        chatId: widget.chatId,
        chat: chat,
        myUserId: myUserId,
        onTap: chat == null
            ? null
            : () => context.push(ChatInfoRoute.locationOf(widget.chatId)),
      ),
      actions: [
        if (chat != null)
          ChatHeaderActions(
            chat: chat,
            me: state?.me,
            onSearch: () => _setSearchMode(on: true),
            onSelectMessages: _startEmptySelection,
          ),
      ],
    );
  }

  /// Back, or Esc: out of whichever mode the header is in.
  void _leaveMode() {
    if (_selectionMode) {
      _clearSelection();
    } else if (_searchMode) {
      _setSearchMode(on: false);
    }

    // Typing goes back where it was: on a desktop the field is the chat's
    // home for the keyboard.
    if (DesktopInput.isDesktop) _composerFocus.requestFocus();
  }

  /// Esc on a desktop, innermost first: the emoji panel, a selection or a
  /// search, the reply or the edit in the composer — and with none of
  /// those left, the chat itself. (The mention list, when it is up, has
  /// already taken its own Esc by the time this runs.)
  void _onEscape() {
    if (_input.showsPanel) {
      _closeEmojiPanel();
      return;
    }
    if (_selectionMode || _searchMode) {
      _leaveMode();
      return;
    }

    final replying =
        ref.read(chatDetailProvider(widget.chatId)).value?.replyTo != null;
    if (replying || ref.read(composerProvider(widget.chatId)).isEditing) {
      _cancelComposerContext();
      return;
    }

    _closeChat();
  }

  /// Leaves the conversation: back to the list on one pane, and on two the
  /// selection goes — the list stays where it is and the right pane goes
  /// back to its placeholder.
  void _closeChat() {
    if (AppLayoutScope.of(context).isTwoPane) {
      context.go(ChatsRoute.location);
      return;
    }
    unawaited(Navigator.of(context).maybePop());
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
    } else {
      // The search field takes the keyboard; the panel would only sit
      // under it.
      _closeEmojiPanel();
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
      // Opened from the menu, a selection starts empty: say what to do
      // rather than "0 selected".
      title: Text(
        selected.isEmpty
            ? l10n.selectMessagesHint
            : l10n.selectedCount(selected.length),
      ),
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
    _screenFocus.requestFocus();
  }

  /// "Select messages" from the menu: the mode, with nothing in it yet.
  void _startEmptySelection() {
    setState(() => _selectedMessageIds = <String>{});
    _screenFocus.requestFocus();
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

    final l10n = AppLocalizations.of(context);
    final useCase = ref.read(forwardMessageUseCaseProvider);
    final failures = await _runBulk(
      label: l10n.bulkForwarding,
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
        return result.match((failure) => failure, (_) => null);
      },
    );
    if (!mounted) return;

    _clearSelection();
    if (failures.isEmpty) {
      AppSnackbar.quiet(
        context,
        l10n.bulkComplete(l10n.bulkForwarding, ordered.length),
      );
      return;
    }
    AppSnackbar.failure(
      context,
      l10n.bulkPartial(
        ordered.length - failures.length,
        ordered.length,
        failures.length,
        friendlyFailureMessage(failures.first, l10n: l10n),
      ),
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

  void _deleteSelected() {
    final selected = _selectedMessageIds;
    if (selected == null || selected.isEmpty) return;
    unawaited(_deleteMessages(selected.toList()));
  }

  /// The one way messages are deleted. A single message from its menu and a
  /// selection from the bar both come here: the same question first, the
  /// same requests, and a refusal said the same way — in the reader's words
  /// rather than the server's (failure_messages).
  Future<void> _deleteMessages(List<String> ids) async {
    if (ids.isEmpty) return;

    final confirmed = await MessageDeleteDialog.confirm(
      context,
      count: ids.length,
    );
    if (!confirmed || !mounted) return;

    final l10n = AppLocalizations.of(context);
    final notifier = ref.read(chatDetailProvider(widget.chatId).notifier);
    final failures = await _runBulk(
      label: l10n.bulkDeleting,
      total: ids.length,
      // One message is one request: a progress dialog for it would only
      // flash. Success needs no word either way — the bubble leaving the
      // feed says it.
      showProgress: ids.length > 1,
      action: (index) => notifier.tryDeleteMessage(ids[index]),
    );
    if (!mounted) return;

    if (_selectionMode) _clearSelection();
    if (failures.isEmpty) return;

    final reason = friendlyFailureMessage(
      failures.first,
      l10n: l10n,
      fallback: l10n.messageDeleteFailed,
    );
    AppSnackbar.failure(
      context,
      ids.length == 1
          ? reason
          : l10n.bulkPartial(
              ids.length - failures.length,
              ids.length,
              failures.length,
              reason,
            ),
    );
  }

  /// Runs [action] for each of [total] items, one request at a time — the
  /// API has no batch form of these (api-docs §5.4) — and hands back what
  /// failed. Reporting is the caller's: what a failure means depends on what
  /// was being done.
  Future<List<Failure>> _runBulk({
    required String label,
    required int total,
    required Future<Failure?> Function(int index) action,
    bool showProgress = true,
  }) async {
    final l10n = AppLocalizations.of(context);
    final progress = ValueNotifier<int>(0);
    final failures = <Failure>[];

    final dialog = showProgress
        ? showDialog<void>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              content: ValueListenableBuilder<int>(
                valueListenable: progress,
                builder: (_, done, _) => Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: AppSpacing.x4),
                    Expanded(
                      child: Text(l10n.bulkProgress(label, done, total)),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    for (var index = 0; index < total; index++) {
      final failure = await action(index);
      if (failure != null) failures.add(failure);
      progress.value = index + 1;
    }

    if (dialog != null) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialog;
    }
    progress.dispose();
    return failures;
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

  // --------------------------------------------------------- physical keys

  /// Enter and ↑ in the composer, on a desktop.
  ///
  /// Enter sends or starts a new line by the reader's choice in Settings
  /// ([SendShortcut]); ↑ in an empty field opens the newest message of
  /// theirs for editing, as in every desktop messenger. Anything else, and
  /// every key with a modifier this does not know, is the field's.
  KeyEventResult _onComposerKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      // An input method is still putting a word together, and the Enter
      // that finishes it is its own.
      if (_textController.value.composing.isValid) {
        return KeyEventResult.ignored;
      }

      final action = ComposerEnterRule.actionFor(
        ref.read(sendShortcutProvider),
        shift: keyboard.isShiftPressed,
        primary: DesktopInput.isPrimaryPressed,
        alt: keyboard.isAltPressed,
      );
      if (action == ComposerEnterAction.newline) return KeyEventResult.ignored;

      // Held down, Enter sends once rather than once per repeat.
      if (event is KeyDownEvent) unawaited(_send());
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp &&
        event is KeyDownEvent &&
        !keyboard.isShiftPressed &&
        !keyboard.isAltPressed &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed &&
        _textController.text.isEmpty &&
        !ref.read(composerProvider(widget.chatId)).isEditing) {
      final state = ref.read(chatDetailProvider(widget.chatId)).value;
      final last = state == null
          ? null
          : lastEditableMessage(state.messages, state.me);
      if (last == null) return KeyEventResult.ignored;

      _startEditing(last);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Ctrl+V in the composer with files or a picture on the clipboard: the
  /// same preview a pick from the paperclip opens. False leaves the paste to
  /// the field — there was only text, or nothing this chat can take.
  Future<bool> _pasteAttachments() async {
    if (ref.read(composerProvider(widget.chatId)).isEditing) return false;

    final uploads = await ref.read(clipboardAttachmentReaderProvider).read();
    if (uploads.isEmpty || !mounted) return false;

    unawaited(_stageUploads(uploads));
    return true;
  }

  /// Files let go of over the chat: whatever of them is a file this device
  /// can read goes where a pick from the paperclip would.
  Future<void> _onFilesDropped(List<String> paths) async {
    final uploads = await LocalFileUploads.ofAll(paths);
    if (uploads.isEmpty || !mounted) return;
    await _stageUploads(uploads);
  }

  // ------------------------------------------------------------ emoji panel

  /// The smiley in the field: keyboard to panel, or panel back to keyboard.
  void _toggleEmojiPanel() {
    if (_input.isEmojiOpen) {
      _input.showKeyboard();
      if (!_composerFocus.hasFocus) _composerFocus.requestFocus();
      return;
    }

    _input.openEmoji();
    // After the frame that turns the field read-only: focused before it,
    // the field would raise the keyboard for a frame and then drop it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _composerFocus.requestFocus();
    });
  }

  /// A tap on the field while the panel holds the keyboard down asks for the
  /// keyboard back.
  void _onComposerFieldTap() {
    if (_input.holdsKeyboard) _input.showKeyboard();
  }

  /// Puts the panel away, and on a phone the caret with it — otherwise the
  /// field, no longer read-only, would raise the keyboard in its place.
  void _closeEmojiPanel() {
    if (!_input.showsPanel) return;
    if (_input.softKeyboard) _composerFocus.unfocus();
    _input.close();
  }

  void _insertEmoji(String emoji) {
    _textController.value = ComposerTextEdits.insert(
      _textController.value,
      emoji,
    );
    ref.read(recentEmojiProvider.notifier).remember(emoji);
  }

  void _deleteBackwards() {
    _textController.value = ComposerTextEdits.backspace(_textController.value);
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

    _updateMention();
  }

  // ---------------------------------------------------------------- mentions

  /// Groups and channels: a direct chat has one other person in it, and
  /// nobody to tell apart with an `@`.
  static bool _mentionsIn(ChatType? type) =>
      type == ChatType.group ||
      type == ChatType.supergroup ||
      type == ChatType.channel;

  /// Re-reads the `@query` under the caret — on every keystroke and every
  /// move of the caret, both of which the controller reports.
  void _updateMention() {
    final chat = ref.read(chatDetailProvider(widget.chatId)).value?.chat;
    var query = _mentionsIn(chat?.type)
        ? MentionSyntax.queryAt(_textController.value)
        : null;

    if (query != null && query == _dismissedMention) query = null;
    if (query == null) _dismissedMention = null;

    if (query?.start != _mention.value?.start ||
        query?.query != _mention.value?.query) {
      _mentionHighlight.value = 0;
    }
    _mention.value = query;
  }

  List<ChatMemberEntity> _mentionCandidatesFor(
    ChatDetailState state,
    int? myUserId,
    MentionQuery? query,
  ) {
    if (query == null) return const [];
    return mentionCandidates(
      state.chat?.members ?? const [],
      query.query,
      myUserId: myUserId,
    );
  }

  Widget _buildMentionSuggestions(ChatDetailState state, int? myUserId) {
    return ValueListenableBuilder<MentionQuery?>(
      valueListenable: _mention,
      builder: (context, query, _) {
        final candidates = _mentionCandidatesFor(state, myUserId, query);
        if (candidates.isEmpty) return const SizedBox.shrink();

        return ChatColumn(
          // Inside the field's tap region, so a click on a row does not
          // first take the caret out of the field it is about to edit.
          child: TextFieldTapRegion(
            child: ValueListenableBuilder<int>(
              valueListenable: _mentionHighlight,
              builder: (context, highlight, _) => MentionSuggestions(
                candidates: candidates,
                // Only where there are arrow keys to move it with.
                highlighted: _input.softKeyboard ? null : highlight,
                onSelected: _pickMention,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Arrows, Enter, Tab and Esc for the list — only while it is showing, so
  /// Enter and the arrows go back to the text the moment it is not.
  Map<ShortcutActivator, VoidCallback> _mentionShortcuts(
    ChatDetailState state,
    int? myUserId,
    MentionQuery? query,
  ) {
    final candidates = _mentionCandidatesFor(state, myUserId, query);
    if (candidates.isEmpty) return const {};

    void move(int by) {
      final count = candidates.length;
      _mentionHighlight.value = (_mentionHighlight.value + by) % count;
    }

    void pick() {
      final index = _mentionHighlight.value.clamp(0, candidates.length - 1);
      _pickMention(candidates[index]);
    }

    return {
      const SingleActivator(LogicalKeyboardKey.arrowDown): () => move(1),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () => move(-1),
      const SingleActivator(LogicalKeyboardKey.enter): pick,
      const SingleActivator(LogicalKeyboardKey.tab): pick,
      const SingleActivator(LogicalKeyboardKey.escape): () {
        _dismissedMention = query;
        _mention.value = null;
      },
    };
  }

  /// Swaps the `@query` for the person's handle and a space.
  void _pickMention(ChatMemberEntity member) {
    final query = _mention.value;
    final username = member.profile?.username;
    if (query == null || username == null) return;

    _textController.value = ComposerTextEdits.replaceRange(
      _textController.value,
      query.start,
      query.end,
      MentionSyntax.insertionFor(username),
    );
    if (!_composerFocus.hasFocus) _composerFocus.requestFocus();
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

    // The message is gone from the composer as of this line — the bubble it
    // becomes is optimistic, so the confirmation has to be too.
    AppHaptics.messageSent();

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
      // The bars were sampled while this was being spoken and there is
      // nowhere on the server to put them (api-docs §5.5), so they are filed
      // against the attachment id — which is the `upload_token` the presign
      // step already handed back.
      onTokens: (tokens) async {
        if (tokens.isEmpty || recording.waveform.isEmpty) return;
        await ref
            .read(voiceLocalStoreProvider)
            .writeWaveform(tokens.first, recording.waveform);
      },
    );
  }

  /// Uploads one attachment that travels alone and sends it on its own.
  ///
  /// `voice` and `video_note` cannot be mixed with anything, including each
  /// other (api-docs §5.5), so they never join whatever is staged — they
  /// replace it and go straight out.
  Future<void> _sendExclusive(
    AttachmentUploadRequestEntity upload,
    MessageType type, {

    /// Called with the confirmed slots before the message goes out, for
    /// anything that has to be filed against the attachment id.
    Future<void> Function(List<String> tokens)? onTokens,
  }) async {
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

    await onTokens?.call(tokens);
    if (!mounted) return;

    AppHaptics.messageSent();
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
    if (result.asFiles) {
      await _sendFiles(result);
    } else {
      await _sendAlbum(result);
    }
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

    AppHaptics.messageSent();
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

  /// Sends a pick "as files": each one a `file` attachment in a message of
  /// its own, since a message carries at most one file (api-docs §5.5). The
  /// caption goes with the last, under the files it is about.
  ///
  /// One at a time, in order: a refusal stops the rest rather than leaving a
  /// gap in the middle of what was sent, and the tray says what happened.
  Future<void> _sendFiles(MediaPreviewResult result) async {
    final notifier = ref.read(chatAttachmentProvider(widget.chatId).notifier);
    final uploads = result.uploads;

    // The caption has left the box for the last of these messages.
    _setText('');
    ref.read(chatDraftsProvider.notifier).clear(widget.chatId);

    for (var index = 0; index < uploads.length; index++) {
      final isLast = index == uploads.length - 1;

      notifier.select([uploads[index]]);
      if (ref.read(chatAttachmentProvider(widget.chatId)).value?.failure !=
          null) {
        return;
      }

      await notifier.upload();
      if (!mounted) return;

      final tokens =
          ref.read(chatAttachmentProvider(widget.chatId)).value?.uploadTokens ??
          const <String>[];
      if (tokens.isEmpty) {
        // Cancelled, or the upload gave up: the caption has not gone yet,
        // so it goes back in the box.
        final caption = result.caption;
        if (caption != null) _setText(caption);
        return;
      }

      AppHaptics.messageSent();
      _composer.markSent();

      await ref
          .read(chatDetailProvider(widget.chatId).notifier)
          .sendMessage(
            content: isLast ? result.caption : null,
            uploadTokens: tokens,
          );
      if (!mounted) return;

      ref.read(confirmedAttachmentTokensProvider.notifier).release(tokens);
      notifier.clear();
    }
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

    await _sendVideoNote(take);
  }

  /// Sends a take, wherever it came from — the sheet, or the composer
  /// button's hold.
  Future<void> _sendVideoNote(VideoNoteTake take) =>
      _sendExclusive(take.upload, MessageType.videoNote);
}

/// "Unblock", on the bar that stands in for the composer of a direct chat
/// with somebody the reader blocked.
class _UnblockPeerButton extends ConsumerWidget {
  const _UnblockPeerButton({required this.chat, required this.peerId});

  final ChatEntity chat;
  final int peerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final busy = ref.watch(isBlockBusyProvider(peerId));

    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
      ),
      onPressed: busy
          ? null
          : () {
              final myUserId = ref.read(authProvider).value?.id;
              BlockActions.unblock(
                context,
                ref,
                userId: peerId,
                name: chatTitleOf(
                  chat,
                  l10n,
                  myUserId: myUserId,
                  peerLocalName: readPeerLocalName(ref, chat, myUserId),
                ),
              );
            },
      child: Text(l10n.unblockUserAction),
    );
  }
}

/// The composer and everything that changes while somebody is typing.
///
/// Split out of [ChatDetailScreen] for one reason: to keep the rebuilds that
/// a keystroke causes inside the bar it happens in.
class _ComposerSection extends ConsumerWidget {
  const _ComposerSection({
    required this.chatId,
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.onCancelContext,
    required this.onAttach,
    required this.onSend,
    required this.onVoiceRecorded,
    required this.onVideoNoteRecorded,
    required this.input,
    required this.onToggleEmoji,
    required this.onFieldTap,
  });

  final String chatId;
  final TextEditingController controller;
  final FocusNode focusNode;
  final ComposerInputController input;
  final MessageEntity? replyTo;

  final VoidCallback onCancelContext;
  final Future<void> Function() onAttach;
  final Future<void> Function() onSend;
  final Future<void> Function(VoiceRecording recording) onVoiceRecorded;
  final Future<void> Function(VideoNoteTake take) onVideoNoteRecorded;
  final VoidCallback onToggleEmoji;
  final VoidCallback onFieldTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final composer = ref.watch(composerProvider(chatId));
    final hasAttachments =
        ref.watch(
          chatAttachmentProvider(chatId).select((it) => it.value?.isReady),
        ) ??
        false;

    // Only whether something is being recorded, not how far along it is: the
    // waveform ticks many times a second and the bar looks the same for all
    // of them.
    final isRecording =
        ref.watch(voiceRecordProvider.select((it) => it.isActive)) ||
        ref.watch(videoNoteRecordProvider.select((it) => it.isActive));

    return ListenableBuilder(
      listenable: input,
      builder: (context, _) => ChatComposer(
        desktop: DesktopInput.isDesktop,
        controller: controller,
        focusNode: focusNode,
        length: composer.length,
        hasAttachments: hasAttachments,
        isRecording: isRecording,
        slowMode: composer.slowMode,
        isSending: composer.isSending,
        replyTo: replyTo,
        editing: composer.editing,
        onCancelContext: onCancelContext,
        // An edit gains no attachments: `PATCH .../messages/{id}/` only
        // carries `content` (api-docs §5.4).
        onAttach: composer.isEditing ? null : onAttach,
        onSend: onSend,
        onVoiceRecorded: composer.isEditing ? null : onVoiceRecorded,
        onVideoNoteRecorded: composer.isEditing ? null : onVideoNoteRecorded,
        isEmojiOpen: input.isEmojiOpen,
        holdsKeyboard: input.holdsKeyboard,
        onToggleEmoji: onToggleEmoji,
        onFieldTap: onFieldTap,
      ),
    );
  }
}

/// Where the composer meets a physical keyboard: a key handler for Enter and
/// ↑, and Ctrl+V taught to bring files and pictures as well as text.
///
/// Only on a desktop — on a phone the soft keyboard's return key starts a
/// new line and the paste menu is the system's, so there this is only
/// [child].
class _DesktopComposerKeys extends StatelessWidget {
  const _DesktopComposerKeys({
    required this.onKey,
    required this.onPaste,
    required this.child,
  });

  final FocusOnKeyEventCallback onKey;

  /// True when it took the paste; false hands it back to the field.
  final Future<bool> Function() onPaste;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DesktopInput.isDesktop) return child;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: onKey,
      child: Actions(
        actions: {PasteTextIntent: _PasteAttachmentsAction(onPaste)},
        child: child,
      ),
    );
  }
}

/// Ctrl+V for the composer: files or a picture first, and the field's own
/// paste — text — when there are none.
///
/// Overrides the text field's action rather than racing its shortcut: the
/// field asks its ancestors before pasting, and the action it would have
/// run arrives here as [callingAction], to be run once the clipboard turns
/// out to hold only text.
class _PasteAttachmentsAction extends ContextAction<PasteTextIntent> {
  _PasteAttachmentsAction(this.onPaste);

  final Future<bool> Function() onPaste;

  @override
  Object? invoke(PasteTextIntent intent, [BuildContext? context]) {
    // Only set for the duration of this call: kept for after the await.
    final fallback = callingAction;

    unawaited(() async {
      if (await onPaste()) return;
      fallback?.invoke(intent);
    }());
    return null;
  }
}
