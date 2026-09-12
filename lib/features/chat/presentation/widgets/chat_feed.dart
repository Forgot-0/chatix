import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_feed_items.dart';
import 'package:chatix/features/chat/presentation/utils/feed_viewport_probe.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_date_separator.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_jump_button.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_message_row.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_pending_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_wallpaper.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The conversation itself: the wallpaper it sits on, the messages, and the
/// three things that float over them — the sticky day, the jump-to-bottom
/// button, and nothing else.
///
/// Everything here is coupled to one scroll position, which is why it lives
/// in one widget. The screen above only composes it with the header, the
/// banners and the composer.
class ChatFeed extends ConsumerStatefulWidget {
  const ChatFeed({
    super.key,
    required this.chatId,
    required this.state,
    required this.myUserId,
    required this.selectionMode,
    required this.selectedIds,
    required this.onStartSelection,
    required this.onToggleSelected,
    required this.onEdit,
    required this.onRefresh,
  });

  final String chatId;
  final ChatDetailState state;
  final int? myUserId;

  final bool selectionMode;
  final Set<String> selectedIds;

  final void Function(String messageId) onStartSelection;
  final void Function(String messageId) onToggleSelected;
  final void Function(MessageEntity message) onEdit;

  final Future<void> Function() onRefresh;

  @override
  ConsumerState<ChatFeed> createState() => _ChatFeedState();
}

class _ChatFeedState extends ConsumerState<ChatFeed>
    with WidgetsBindingObserver {
  /// How far from the bottom the reader has to be before scrolling back by
  /// hand stops being reasonable and the button earns its place.
  static const double _detachViewports = 1.5;

  /// How close to the far end of the loaded window the reader gets before the
  /// next page starts fetching.
  static const double _pagingSlack = 200;

  /// Scroll distance over which the wallpaper completes one drift cycle.
  /// Long on purpose: the pattern should breathe, not slide.
  static const double _parallaxPeriod = 900;

  static const int _maxScrollSteps = 12;

  /// How long after the last scroll event the list counts as settled.
  static const Duration _settleDelay = Duration(milliseconds: 700);

  /// How long a jumped-to message stays lit before it fades back.
  static const Duration _flash = Duration(milliseconds: 1400);

  final _scrollController = ScrollController();
  final _listKey = GlobalKey();

  final _stickyDay = ValueNotifier<DateTime?>(null);
  final _isMoving = ValueNotifier<bool>(false);
  final _newBelow = ValueNotifier<int?>(null);
  final _parallax = ValueNotifier<double>(0);

  /// The rows the list is showing, derived from [widget.state].
  ///
  /// Kept rather than recomputed per call because the scroll callbacks run
  /// between frames and need them, and rebuilt only when the window they come
  /// from actually changed — flattening a thousand messages on every
  /// selection tap or reply banner is work nobody asked for.
  List<ChatFeedItem> _items = const [];
  Map<String, int> _indexByKey = const {};

  List<MessageEntity>? _itemsFrom;
  int _itemsPendingCount = -1;
  bool _itemsCanLoadMore = false;
  int? _itemsUnreadAnchor;
  int? _itemsMyUserId;
  ChatType? _itemsChatType;

  bool _reduceMotion = false;

  /// Highest seq the viewport has really shown. Drives the badge; the read
  /// cursor is the provider's business.
  int? _seenSeq;

  String? _targetItemKey;
  double _targetAlignment = 0.4;
  int _scrollSteps = 0;

  bool _probeScheduled = false;

  /// Whether the opening scroll has been decided and finished.
  ///
  /// Nothing is reported as read before it has. The list renders at the
  /// bottom for the frame or two it takes to find the unread boundary, and a
  /// probe in that window would report the newest message and wipe the badge
  /// the reader opened the chat to answer.
  bool _openHandled = false;
  bool _opened = false;

  Completer<void>? _targetReached;

  Timer? _settleTimer;
  Timer? _flashTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openAtUnread());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settleTimer?.cancel();
    _flashTimer?.cancel();
    _finishTarget(null);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _stickyDay.dispose();
    _isMoving.dispose();
    _newBelow.dispose();
    _parallax.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to a chat that was left open is the one moment where what
    // is on screen has been read without a single scroll event to say so.
    if (state == AppLifecycleState.resumed) _scheduleProbe();
  }

  @override
  void didUpdateWidget(covariant ChatFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    final highlight = widget.state.highlightMessageId;
    if (highlight != null && highlight != oldWidget.state.highlightMessageId) {
      _flashAt(highlight);
    }

    if (widget.state.messages != oldWidget.state.messages) {
      if (!_openHandled) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _openAtUnread());
      }
      _scheduleProbe();
      _refreshBadge();
    }
  }

  @override
  Widget build(BuildContext context) {
    _reduceMotion = MediaQuery.disableAnimationsOf(context);

    _rebuildItems();

    return Stack(
      children: [
        Positioned.fill(
          child: ChatWallpaper(
            seed: widget.chatId.hashCode,
            parallax: _reduceMotion ? null : _parallax,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: _items.isEmpty ? _buildEmpty(context) : _buildList(),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(
            child: ChatStickyDate(day: _stickyDay, isMoving: _isMoving),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: ChatJumpToBottomButton(
            newBelow: _newBelow,
            onPressed: _scrollToBottom,
          ),
        ),
      ],
    );
  }

  void _rebuildItems() {
    final state = widget.state;

    // The provider hands out a new list whenever the window changes, so
    // identity is enough to tell a real change from a rebuild.
    final unchanged =
        identical(state.messages, _itemsFrom) &&
        state.pending.length == _itemsPendingCount &&
        state.canLoadMore == _itemsCanLoadMore &&
        state.unreadAnchorSeq == _itemsUnreadAnchor &&
        widget.myUserId == _itemsMyUserId &&
        state.chat?.type == _itemsChatType;
    if (unchanged) return;

    _itemsFrom = state.messages;
    _itemsPendingCount = state.pending.length;
    _itemsCanLoadMore = state.canLoadMore;
    _itemsUnreadAnchor = state.unreadAnchorSeq;
    _itemsMyUserId = widget.myUserId;
    _itemsChatType = state.chat?.type;

    _items = ChatFeedBuilder.build(
      messages: state.messages,
      pendingKeys: [
        for (final pending in state.pending) pending.idempotencyKey,
      ],
      canLoadMore: state.canLoadMore,
      unreadAnchorSeq: state.unreadAnchorSeq,
      myUserId: widget.myUserId,
      isGroupChat: state.chat?.type != ChatType.direct,
    );
    _indexByKey = {for (var i = 0; i < _items.length; i++) _items[i].key: i};
  }

  Widget _buildEmpty(BuildContext context) {
    return ListView(
      controller: _scrollController,
      children: [
        const SizedBox(height: 120),
        Center(child: Text(AppLocalizations.of(context).noMessagesYet)),
      ],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      key: _listKey,
      controller: _scrollController,
      reverse: true,
      itemCount: _items.length,
      // Nothing in a message bubble holds state worth keeping alive off
      // screen, and a thousand kept-alive rows is a thousand rows laid out
      // forever.
      addAutomaticKeepAlives: false,
      // Each bubble raises its own boundary; separators and dividers do not
      // need one of their own.
      addRepaintBoundaries: false,
      // Rows are keyed by message id, so a page arriving above the viewport
      // shifts every index by thirty without rebuilding a single row.
      findChildIndexCallback: (key) =>
          key is ValueKey<String> ? _indexByKey[key.value] : null,
      itemBuilder: _buildRow,
    );
  }

  Widget _buildRow(BuildContext context, int index) {
    final item = _items[index];

    return KeyedSubtree(
      key: ValueKey<String>(item.key),
      child: switch (item) {
        // Its own layer: a spinner that never stops would otherwise repaint
        // the whole list with every turn.
        FeedLoadMoreItem() => const RepaintBoundary(
          child: AppLoadMoreIndicator(),
        ),
        FeedPendingItem() => RepaintBoundary(
          child: ChatPendingBubble(
            pending: widget.state.pending[item.index],
            chatId: widget.chatId,
          ),
        ),
        FeedMessageItem() => ChatMessageRow(
          chatId: widget.chatId,
          item: item,
          state: widget.state,
          selectionMode: widget.selectionMode,
          isSelected: widget.selectedIds.contains(item.message.id),
          onStartSelection: widget.onStartSelection,
          onToggleSelected: widget.onToggleSelected,
          onEdit: widget.onEdit,
        ),
      },
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - _pagingSlack) {
      ref.read(chatDetailProvider(widget.chatId).notifier).loadMore();
    }

    if (!_reduceMotion) {
      _parallax.value =
          ChatWallpaper.maxParallax *
          math.sin(position.pixels / _parallaxPeriod);
    }

    _isMoving.value = true;
    _settleTimer?.cancel();
    _settleTimer = Timer(_settleDelay, () {
      if (mounted) _isMoving.value = false;
    });

    _refreshBadge();
    _scheduleProbe();
  }

  /// Asks the list what it is showing, once per frame at most.
  ///
  /// Scroll callbacks fire before the frame they caused is laid out, so the
  /// answer is only trustworthy afterwards.
  void _scheduleProbe() {
    if (_probeScheduled) return;
    _probeScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _probeScheduled = false;
      _probe();
    });
  }

  void _probe() {
    if (!mounted || !_opened) return;

    final range = FeedViewportProbe.of(_listKey.currentContext);
    if (range == null) return;

    _stickyDay.value = ChatFeedBuilder.dayAt(_items, range.last);

    final seq = _highestVisibleSeq(range);
    if (seq == null) return;

    if (_seenSeq == null || seq > _seenSeq!) {
      _seenSeq = seq;
      _refreshBadge();
    }

    // A chat left open in the background is not being read, and clearing
    // someone's badge for them is worse than clearing it a moment late.
    if (!_isAppActive) return;
    ref.read(chatDetailProvider(widget.chatId).notifier).reportRead(seq);
  }

  bool get _isAppActive {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  /// Rows run newest first, so the lowest visible index carries the highest
  /// seq. Pending rows sit below them and have no seq at all.
  int? _highestVisibleSeq(FeedVisibleRange range) {
    for (var i = range.first; i <= range.last && i < _items.length; i++) {
      final item = _items[i];
      if (item is FeedMessageItem) return item.message.seq;
    }
    return null;
  }

  void _refreshBadge() {
    if (!mounted || !_scrollController.hasClients) return;

    final position = _scrollController.position;
    final detached =
        position.pixels > position.viewportDimension * _detachViewports;

    _newBelow.value = detached
        ? ChatFeedBuilder.countNewerThan(
            widget.state.messages,
            seenSeq: _seenSeq,
            myUserId: widget.myUserId,
          )
        : null;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: ChatixTheme.duration,
      curve: ChatixTheme.curve,
    );
  }

  void _flashAt(String messageId) {
    unawaited(_scrollToItem('message:$messageId', alignment: 0.4));

    _flashTimer?.cancel();
    _flashTimer = Timer(_flash, () {
      if (!mounted) return;
      ref.read(chatDetailProvider(widget.chatId).notifier).clearHighlight();
    });
  }

  /// Opens the chat where reading stopped rather than at the newest message.
  ///
  /// Runs once. The divider is usually inside the freshest page already; when
  /// more went unread than one page holds, the window has to be pulled back
  /// to it first.
  Future<void> _openAtUnread() async {
    if (_openHandled || !mounted) return;
    _openHandled = true;

    try {
      final state = widget.state;
      if (state.unreadAtOpen <= 0 || state.unreadAnchorSeq == null) return;

      if (ChatFeedBuilder.unreadIndexOf(_items) == null) {
        final pulled = await ref
            .read(chatDetailProvider(widget.chatId).notifier)
            .loadUnreadWindow();
        if (!pulled || !mounted) return;

        // The replacement window reaches this widget as a rebuild; the rows
        // it produces exist only after that frame.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
      }

      final index = ChatFeedBuilder.unreadIndexOf(_items);
      if (index == null) return;

      // Aligned to the top edge: the divider is part of that row, so the
      // first unread message lands directly under it with the rest below.
      await _scrollToItem(_items[index].key, alignment: 1);
    } finally {
      if (mounted) {
        _opened = true;
        _probe();
      }
    }
  }

  /// Brings a row onto the screen, completing once it has stopped moving.
  Future<void> _scrollToItem(String itemKey, {required double alignment}) {
    _finishTarget(null);

    final reached = Completer<void>();
    _targetReached = reached;
    _targetItemKey = itemKey;
    _targetAlignment = alignment;
    _scrollSteps = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepTowardTarget());
    return reached.future;
  }

  void _finishTarget(Future<void>? animation) {
    final reached = _targetReached;
    _targetReached = null;
    if (reached == null || reached.isCompleted) return;

    if (animation == null) {
      reached.complete();
      return;
    }
    animation.whenComplete(() {
      if (!reached.isCompleted) reached.complete();
    });
  }

  /// Walks the list towards a row that may not be built yet.
  ///
  /// Rows have variable height, so there is no offset to jump straight to.
  /// Each step climbs most of a viewport and looks again; once the row exists
  /// the viewport can say exactly where it is.
  void _stepTowardTarget() {
    if (!mounted) {
      _finishTarget(null);
      return;
    }
    if (_targetItemKey == null) return;

    final index = _indexByKey[_targetItemKey];
    if (index == null || !_scrollController.hasClients) {
      _targetItemKey = null;
      _finishTarget(null);
      return;
    }

    final child = FeedViewportProbe.childAt(_listKey.currentContext, index);
    if (child != null) {
      _targetItemKey = null;

      final position = _scrollController.position;
      final reveal = RenderAbstractViewport.of(
        child,
      ).getOffsetToReveal(child, _targetAlignment).offset;

      _finishTarget(
        _scrollController.animateTo(
          reveal.clamp(position.minScrollExtent, position.maxScrollExtent),
          duration: ChatixTheme.duration,
          curve: ChatixTheme.curve,
        ),
      );
      return;
    }

    if (++_scrollSteps > _maxScrollSteps) {
      _targetItemKey = null;
      _finishTarget(null);
      return;
    }

    final position = _scrollController.position;
    _scrollController.jumpTo(
      (position.pixels + position.viewportDimension * 0.8).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _stepTowardTarget());
  }
}
