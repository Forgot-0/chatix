import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_state_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_exit_options.dart';
import 'package:chatix/features/chat/presentation/utils/chat_invite_link.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_shared_content.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/profile/chat_profile_actions.dart';
import 'package:chatix/features/chat/presentation/widgets/profile/chat_profile_header.dart';
import 'package:chatix/features/chat/presentation/widgets/profile/chat_shared_content_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about one chat on one page: who it is, what it has shared,
/// and the handful of things that can be done to it.
///
/// One [CustomScrollView] rather than a [NestedScrollView] with a
/// [TabBarView]: the tabs choose which sliver goes at the bottom of the same
/// scroll, so the header collapses once for the whole page instead of once
/// per tab, and switching tabs keeps the reader where they were.
class ChatProfileScreen extends ConsumerStatefulWidget {
  const ChatProfileScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatProfileScreen> createState() => _ChatProfileScreenState();
}

class _ChatProfileScreenState extends ConsumerState<ChatProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  /// True while a leave or a delete is in flight, so neither can be asked
  /// for twice.
  bool _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SharedContentTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);

    // Presence costs a request per chat, so it is asked for once, here,
    // and only for the kind of chat that has a single other person in it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chat = ref.read(chatDetailProvider(widget.chatId)).value?.chat;
      if (chat?.type != ChatType.direct) return;
      ref.read(chatPresenceProvider.notifier).ensureFresh(widget.chatId);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  SharedContentTab get _tab => SharedContentTab.values[_tabController.index];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(chatDetailProvider(widget.chatId));

    // Only the loaded page draws its own bar: the header *is* the bar, and
    // it needs a chat to draw. Until there is one there is an ordinary
    // AppBar, so there is always a way back.
    return detail.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.chatInfo)),
        body: const AppListSkeleton(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.chatInfo)),
        body: AppErrorState(
          error: error,
          fallbackMessage: l10n.chatLoadFailed,
          onRetry: () =>
              ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
        ),
      ),
      data: (state) {
        final chat = state.chat;
        if (chat == null) {
          return Scaffold(
            appBar: AppBar(title: Text(l10n.chatInfo)),
            body: AppEmptyState(title: l10n.chatLoadFailed),
          );
        }
        return Scaffold(body: _profile(l10n, chat, state.me));
      },
    );
  }

  Widget _profile(AppLocalizations l10n, ChatEntity chat, ChatMemberEntity? me) {
    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final content = ref.watch(chatSharedContentProvider(widget.chatId));
    final canUpdate = hasChatPermission(chat, me, ChatPermissions.chatUpdate);

    final description = chat.description?.trim();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: ChatProfileHeader(
            chat: chat,
            myUserId: myUserId,
            title: chatTitleOf(chat, l10n, myUserId: myUserId),
            subtitle: _subtitle(l10n, chat),
            topPadding: MediaQuery.paddingOf(context).top,
            onBack: _back,
            trailing: canUpdate
                ? IconButton(
                    tooltip: l10n.chatSettings,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        context.push(ChatSettingsRoute.locationOf(chat.id)),
                  )
                : null,
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              if (description != null && description.isNotEmpty)
                _DescriptionBlock(description: description),
              if (chat.isPublic) _InviteLinkBlock(chatId: chat.id),
              ChatProfileActionsRow(actions: _actions(l10n, chat, me)),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.membersTitle),
                subtitle: Text(l10n.membersCount(chat.memberCount)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(ChatMembersRoute.locationOf(chat.id)),
              ),
              const Divider(height: 1),
              _DangerZone(
                chat: chat,
                me: me,
                busy: _isLeaving,
                onLeave: _leave,
                onDelete: _delete,
              ),
              const Divider(height: 1),
            ],
          ),
        ),

        SliverPersistentHeader(
          pinned: true,
          delegate: _TabsHeader(
            TabBar(
              controller: _tabController,
              tabs: [
                for (final tab in SharedContentTab.values)
                  Tab(text: _tabLabel(l10n, tab, content.countOf(tab))),
              ],
            ),
          ),
        ),

        ChatSharedContentSliver(
          key: ValueKey<SharedContentTab>(_tab),
          chatId: widget.chatId,
          tab: _tab,
          content: content,
        ),
      ],
    );
  }

  String _tabLabel(AppLocalizations l10n, SharedContentTab tab, int count) {
    final name = switch (tab) {
      SharedContentTab.media => l10n.sharedMedia,
      SharedContentTab.files => l10n.sharedFiles,
      SharedContentTab.links => l10n.sharedLinks,
      SharedContentTab.voice => l10n.sharedVoice,
    };
    return count == 0 ? name : '$name $count';
  }

  /// The line under the name: who is there, or whether they are here.
  String _subtitle(AppLocalizations l10n, ChatEntity chat) {
    if (chat.type == ChatType.direct) {
      final online = ref.watch(chatPeerOnlineProvider(chat.id));
      return online == true ? l10n.onlineNow : l10n.chatDirect;
    }
    return '${chatTypeLabel(chat.type, l10n)} · '
        '${l10n.membersCount(chat.memberCount)}';
  }

  List<ChatProfileAction> _actions(
    AppLocalizations l10n,
    ChatEntity chat,
    ChatMemberEntity? me,
  ) {
    final muted = ref.watch(chatRowStateProvider(chat.id))?.isMutedByMe;

    return [
      ChatProfileAction(
        icon: Icons.call_outlined,
        label: l10n.callTitle,
        onPressed: hasChatPermission(chat, me, ChatPermissions.callJoin)
            ? () => context.push(ChatCallRoute.locationOf(chat.id))
            : null,
      ),
      ChatProfileAction(
        icon: Icons.search,
        label: l10n.searchInChat,
        onPressed: _openSearch,
      ),
      ChatProfileAction(
        icon: muted == true
            ? Icons.notifications_off_outlined
            : Icons.notifications_none,
        label: l10n.notifications,
        onPressed: () => _openNotifications(muted),
      ),
      ChatProfileAction(
        icon: Icons.photo_library_outlined,
        label: l10n.sharedMedia,
        onPressed: () => _jumpToTab(SharedContentTab.media),
      ),
    ];
  }

  void _jumpToTab(SharedContentTab tab) {
    _tabController.animateTo(tab.index);

    if (!_scrollController.hasClients) return;

    // Far enough to put the tab strip under the collapsed bar, or as far as
    // the page goes when there is less to scroll than that.
    const double enough = 400;
    final double extent = _scrollController.position.maxScrollExtent;

    _scrollController.animateTo(
      extent < enough ? extent : enough,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// In-chat search lives in the chat screen's app bar, so this asks that
  /// screen to open it and goes back to it.
  void _openSearch() {
    ref.read(chatSearchRequestProvider.notifier).open(widget.chatId);
    _back();
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ChatDetailRoute(widget.chatId).location);
    }
  }

  Future<void> _openNotifications(bool? muted) async {
    final l10n = AppLocalizations.of(context);

    final choice = await showModalBottomSheet<Duration?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.notifications),
              subtitle: Text(
                muted == true ? l10n.chatMutedLabel : l10n.chatNotMutedLabel,
              ),
            ),
            const Divider(height: 1),
            for (final option in _muteOptions)
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: Text(_muteLabel(l10n, option)),
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(l10n.unmuteChat),
              onTap: () => Navigator.of(sheetContext).pop(Duration.zero),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final unmute = choice == Duration.zero;
    final failure = await ref
        .read(chatStateActionsProvider)
        .setMuted(
          widget.chatId,
          muted: !unmute,
          // "Forever" is a date far enough out that nobody reaches it, which
          // is the shape the field has (api-docs §5.2).
          until: unmute ? null : DateTime.now().add(choice),
        );

    if (!mounted) return;
    if (failure != null) {
      _toast(friendlyFailureMessage(failure, fallback: l10n.errorOccurred));
      return;
    }
    _toast(unmute ? l10n.chatUnmutedToast : l10n.chatMutedToast);
  }

  static const List<Duration> _muteOptions = [
    Duration(hours: 1),
    Duration(hours: 8),
    Duration(days: 365 * 10),
  ];

  String _muteLabel(AppLocalizations l10n, Duration option) {
    if (option == const Duration(hours: 1)) return l10n.muteForHour;
    if (option == const Duration(hours: 8)) return l10n.muteForEightHours;
    return l10n.muteForever;
  }

  Future<void> _leave() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.leaveChat, l10n.leaveChatConfirm)) return;

    setState(() => _isLeaving = true);
    final result = await ref
        .read(leaveChatUseCaseProvider)
        .execute(widget.chatId);

    if (!mounted) return;
    setState(() => _isLeaving = false);
    _afterRemoval(result);
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.deleteChat, l10n.deleteChatConfirm)) return;

    setState(() => _isLeaving = true);
    final result = await ref
        .read(deleteChatUseCaseProvider)
        .execute(widget.chatId);

    if (!mounted) return;
    setState(() => _isLeaving = false);
    _afterRemoval(result);
  }

  void _afterRemoval(Either<Failure, void> result) {
    final l10n = AppLocalizations.of(context);

    result.match(
      (failure) => _toast(
        chatFailureMessage(failure) ??
            friendlyFailureMessage(failure, fallback: l10n.errorOccurred),
      ),
      (_) {
        ref.read(chatListProvider.notifier).refresh();
        context.go(ChatsRoute.location);
      },
    );
  }

  Future<bool> _confirm(String title, String body) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(title),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DescriptionBlock extends StatelessWidget {
  const _DescriptionBlock({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).chatDescription,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(description, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

/// The link to a public chat, and what it is honestly good for.
class _InviteLinkBlock extends StatelessWidget {
  const _InviteLinkBlock({required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final link = ChatInviteLink.of(chatId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatInviteLink,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 6),
          Material(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _copy(context, link),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        link,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.chatInviteLinkHint,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _copy(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).chatInviteLinkCopied)),
    );
  }
}

/// Leaving, and deleting.
///
/// ⚠️ The chat's creator cannot leave: `Chat.leave()` compares the caller
/// with `created_by` and answers `403 CHAT_ACCESS_DENIED`, and no endpoint
/// changes `created_by` (api-docs §5.2). So a creator is not offered the
/// door at all — they are told why, and offered the only exit there is.
class _DangerZone extends StatelessWidget {
  const _DangerZone({
    required this.chat,
    required this.me,
    required this.busy,
    required this.onLeave,
    required this.onDelete,
  });

  final ChatEntity chat;
  final ChatMemberEntity? me;
  final bool busy;
  final VoidCallback onLeave;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final options = ChatExitOptions.of(chat, me);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.canLeave)
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(l10n.leaveChat, style: TextStyle(color: scheme.error)),
            enabled: !busy,
            onTap: onLeave,
          ),
        if (options.notice != ChatExitNotice.none)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              options.notice == ChatExitNotice.creatorMustDelete
                  ? l10n.leaveChatOwnerBlocked
                  : l10n.leaveChatOwnerStuck,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        if (options.canDelete)
          ListTile(
            leading: Icon(Icons.delete_outline, color: scheme.error),
            title: Text(l10n.deleteChat, style: TextStyle(color: scheme.error)),
            enabled: !busy,
            onTap: onDelete,
          ),
      ],
    );
  }
}

/// Holds the tab strip under the collapsed header while the page scrolls.
class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader(this.tabBar);

  final TabBar tabBar;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabsHeader oldDelegate) =>
      oldDelegate.tabBar != tabBar;
}
