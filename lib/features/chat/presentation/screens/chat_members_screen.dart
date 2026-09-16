import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/providers/direct_chat_opener.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_roster.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/member_role_badge.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Who is in one chat, grouped by what they are allowed to do.
///
/// Two sources, because the API disagrees with itself about banned members:
/// the paged `GET /chats/{id}/members/` drops them entirely, while
/// `ChatDetailDTO.members` keeps them with `is_banned: true` (api-docs §5.3).
/// The provider loads both; the banned block is built from the second one, so
/// it is not permanently empty.
class ChatMembersScreen extends ConsumerStatefulWidget {
  const ChatMembersScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends ConsumerState<ChatMembersScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  String _query = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMembersProvider(widget.chatId).notifier).loadMore();
    }
  }

  ChatMembersController get _notifier =>
      ref.read(chatMembersProvider(widget.chatId).notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final membersState = ref.watch(chatMembersProvider(widget.chatId));

    final loaded = membersState.value;
    final chat = loaded?.chat;

    final canInvite =
        loaded != null &&
        hasChatPermission(chat, loaded.me, ChatPermissions.memberInvite) &&
        chatHasRoomForMembers(chat, knownMembers: loaded.knownMemberCount);

    // A one-to-one chat holds two people (api-docs §5.1); a search field over
    // it would be furniture.
    final showsSearch = chat != null && chat.type != ChatType.direct;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.membersTitle),
            if (chat != null)
              Text(
                l10n.membersCount(chat.memberCount),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        bottom: showsSearch
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: _SearchField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                ),
              )
            : null,
      ),
      body: membersState.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.membersLoadFailed,
          onRetry: _notifier.refresh,
        ),
        data: (state) => _list(l10n, state, canInvite: canInvite),
      ),
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              onPressed: () =>
                  context.push(ChatInviteRoute.locationOf(widget.chatId)),
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.addMember),
            )
          : null,
    );
  }

  Widget _list(
    AppLocalizations l10n,
    ChatMembersState state, {
    required bool canInvite,
  }) {
    final sections = buildMemberSections(
      members: state.members,
      banned: state.banned,
      query: _query,
    );

    if (sections.isEmpty) {
      return RefreshIndicator(
        onRefresh: _notifier.refresh,
        child: _query.trim().isEmpty
            ? _EmptyMembersView(
                canInvite: canInvite,
                onInvite: () =>
                    context.push(ChatInviteRoute.locationOf(widget.chatId)),
              )
            : AppEmptyState(
                icon: Icons.person_search_outlined,
                title: l10n.membersSearchEmpty(_query.trim()),
                message: state.canLoadMore
                    ? l10n.membersSearchLoadedOnly
                    : null,
              ),
      );
    }

    // Looked up once: it walks the roster, and the roster can be long.
    final me = state.me;

    final rows = <Widget>[];
    for (final section in sections) {
      rows.add(
        _SectionHeader(
          title: _sectionTitle(l10n, section.section),
          subtitle: section.section == MemberSection.banned
              ? l10n.membersBannedHint
              : null,
          count: section.members.length,
        ),
      );
      for (final member in section.members) {
        rows.add(
          _MemberTile(
            chat: state.chat,
            me: me,
            myUserId: state.myUserId,
            member: member,
            isOnline: state.isOnline(member.userId),
            onTap: () => _openActions(state, member),
          ),
        );
      }
    }

    if (state.isLoadingMore) {
      rows.add(const AppLoadMoreIndicator());
    } else if (state.canLoadMore) {
      // While a search is on, the filtered list can be too short to scroll,
      // and scrolling is what normally fetches the next page. The server has
      // no member search to fall back on (api-docs §5.3), so the rest of the
      // roster is fetched on request instead.
      rows.add(
        _query.trim().isEmpty
            ? const AppLoadMoreIndicator()
            : _LoadMoreForSearch(
                note: l10n.membersSearchLoadedOnly,
                label: l10n.membersLoadMore,
                onPressed: _notifier.loadMore,
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: _notifier.refresh,
      child: ListView.builder(
        controller: _scrollController,
        // Room under the last row for the invite button to sit over.
        padding: EdgeInsets.only(bottom: canInvite ? 88 : 0),
        itemCount: rows.length,
        itemBuilder: (context, index) => rows[index],
      ),
    );
  }

  String _sectionTitle(AppLocalizations l10n, MemberSection section) =>
      switch (section) {
        MemberSection.administration => l10n.membersSectionAdmins,
        MemberSection.members => l10n.membersSectionMembers,
        MemberSection.banned => l10n.membersSectionBanned,
      };

  /// The long-press sheet — also what a tap opens, since a list of names with
  /// nothing behind a tap is a dead end.
  Future<void> _openActions(
    ChatMembersState state,
    ChatMemberEntity member,
  ) async {
    final l10n = AppLocalizations.of(context);

    final actions = memberActionsFor(
      chat: state.chat,
      me: state.me,
      target: member,
      myUserId: state.myUserId,
    );
    if (actions.isEmpty) return;

    final choice = await showModalBottomSheet<ChatMemberAction>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        // Scrollable: a full set of actions plus the header is taller than
        // the half-screen a bottom sheet gets on a short phone.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: ChatAvatar.profile(
                  member.profile,
                  userId: member.userId,
                ),
                title: Text(member.displayLabel),
                subtitle: Text(chatRoleLabel(member.role, l10n)),
              ),
              const Divider(height: 1),
              for (final action in actions)
                ListTile(
                  leading: Icon(
                    _actionIcon(action),
                    color: _isDestructive(action)
                        ? Theme.of(sheetContext).colorScheme.error
                        : null,
                  ),
                  title: Text(
                    _actionLabel(l10n, action),
                    style: _isDestructive(action)
                        ? TextStyle(
                            color: Theme.of(sheetContext).colorScheme.error,
                          )
                        : null,
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(action),
                ),
            ],
          ),
        ),
      ),
    );

    if (choice == null || !mounted) return;
    await _run(choice, state, member);
  }

  IconData _actionIcon(ChatMemberAction action) => switch (action) {
    ChatMemberAction.openProfile => Icons.person_outline,
    ChatMemberAction.message => Icons.chat_bubble_outline,
    ChatMemberAction.changeRole => Icons.admin_panel_settings_outlined,
    ChatMemberAction.kick => Icons.person_remove_outlined,
    ChatMemberAction.ban => Icons.block,
    ChatMemberAction.unban => Icons.lock_open_outlined,
  };

  bool _isDestructive(ChatMemberAction action) =>
      action == ChatMemberAction.kick || action == ChatMemberAction.ban;

  String _actionLabel(AppLocalizations l10n, ChatMemberAction action) =>
      switch (action) {
        ChatMemberAction.openProfile => l10n.memberOpenProfile,
        ChatMemberAction.message => l10n.memberMessagePrivately,
        ChatMemberAction.changeRole => l10n.changeRole,
        ChatMemberAction.kick => l10n.kickMember,
        ChatMemberAction.ban => l10n.banMember,
        ChatMemberAction.unban => l10n.banLift,
      };

  Future<void> _run(
    ChatMemberAction action,
    ChatMembersState state,
    ChatMemberEntity member,
  ) async {
    switch (action) {
      case ChatMemberAction.openProfile:
        // The handle rides along: `ProfileDTO` has none, and this list
        // does (`ChatProfileDTO.username`, api-docs §5.3).
        await context.push(
          ProfileDetailRoute(
            member.userId,
            username: member.profile?.username,
          ).location,
        );

      case ChatMemberAction.message:
        await _message(member);

      case ChatMemberAction.changeRole:
        await _changeRole(state, member);

      case ChatMemberAction.kick:
        await _kick(member);

      case ChatMemberAction.ban:
        await _ban(member);

      case ChatMemberAction.unban:
        await _unban(member);
    }
  }

  Future<void> _message(ChatMemberEntity member) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final result = await resolveDirectChatWith(ref, member.userId);
    if (!mounted) return;

    result.match(
      (failure) => messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyFailureMessage(failure, fallback: l10n.startChatFailed),
          ),
        ),
      ),
      (chatId) => context.push(ChatDetailRoute(chatId).location),
    );
  }

  Future<void> _changeRole(
    ChatMembersState state,
    ChatMemberEntity member,
  ) async {
    final l10n = AppLocalizations.of(context);

    final role = await showDialog<ChatRole>(
      context: context,
      builder: (dialogContext) => _RolePickerDialog(
        current: member.role,
        roles: assignableRolesFor(state.me),
        isOwner: state.me?.role == ChatRole.owner,
      ),
    );
    if (role == null || !mounted || role == member.role) return;

    await _guard(
      () => _notifier.changeRole(member.userId, role),
      success: l10n.memberRoleChanged(
        member.displayLabel,
        chatRoleLabel(role, l10n),
      ),
    );
  }

  Future<void> _kick(ChatMemberEntity member) async {
    final l10n = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.memberKickConfirmTitle(member.displayLabel)),
        content: Text(l10n.memberKickConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.kickMember),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _guard(
      () => _notifier.kickMember(member.userId),
      success: l10n.memberKicked(member.displayLabel),
    );
  }

  Future<void> _ban(ChatMemberEntity member) async {
    final l10n = AppLocalizations.of(context);

    final request = await showDialog<_BanRequest>(
      context: context,
      builder: (dialogContext) => const _BanDialog(),
    );
    if (request == null || !mounted) return;

    await _guard(
      () => _notifier.banMember(
        member.userId,
        reason: request.reason,
        bannedTo: request.bannedTo,
      ),
      success: l10n.memberBannedToast(member.displayLabel),
    );
  }

  Future<void> _unban(ChatMemberEntity member) async {
    final l10n = AppLocalizations.of(context);

    await _guard(
      () => _notifier.unbanMember(member.userId),
      success: l10n.memberUnbanned(member.displayLabel),
    );
  }

  /// Runs one moderation call and says what came of it either way.
  Future<void> _guard(
    Future<void> Function() action, {
    required String success,
  }) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on Failure catch (failure) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            friendlyFailureMessage(failure, fallback: l10n.memberActionFailed),
          ),
        ),
      );
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: l10n.membersSearchHint,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: l10n.clear,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.subtitle,
  });

  final String title;
  final int count;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              Text(
                '$count',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadMoreForSearch extends StatelessWidget {
  const _LoadMoreForSearch({
    required this.note,
    required this.label,
    required this.onPressed,
  });

  final String note;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        children: [
          Text(
            note,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextButton(onPressed: onPressed, child: Text(label)),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.chat,
    required this.me,
    required this.myUserId,
    required this.member,
    required this.isOnline,
    required this.onTap,
  });

  final ChatEntity? chat;
  final ChatMemberEntity? me;
  final int? myUserId;
  final ChatMemberEntity member;
  final bool isOnline;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final username = member.profile?.username?.trim();
    final hasActions = memberActionsFor(
      chat: chat,
      me: me,
      target: member,
      myUserId: myUserId,
    ).isNotEmpty;

    final badges = <Widget>[
      if (MemberRoleBadge.isWorthShowing(member.role))
        MemberRoleBadge(role: member.role),
      if (member.isMuted) const MemberMutedBadge(),
      if (member.isBanned) const MemberBannedBadge(),
    ];

    return ListTile(
      leading: ChatAvatar.profile(
        member.profile,
        userId: member.userId,
        isOnline: isOnline,
        onlineLabel: l10n.onlineNow,
      ),
      title: Text(member.displayLabel, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (username != null && username.isNotEmpty)
            Text(
              '@$username',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (badges.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x1),
            Wrap(
              spacing: AppSpacing.x1,
              runSpacing: AppSpacing.x1,
              children: badges,
            ),
          ],
        ],
      ),
      isThreeLine: badges.isNotEmpty && username != null && username.isNotEmpty,
      trailing: hasActions
          ? Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant)
          : null,
      onTap: hasActions ? onTap : null,
      onLongPress: hasActions ? onTap : null,
    );
  }
}

/// Only the roles this moderator may actually hand out (api-docs §5.3), so a
/// forbidden one is never offered and then refused with a `403`.
class _RolePickerDialog extends StatelessWidget {
  const _RolePickerDialog({
    required this.current,
    required this.roles,
    required this.isOwner,
  });

  final ChatRole? current;
  final List<ChatRole> roles;
  final bool isOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return RadioGroup<ChatRole>(
      groupValue: current,
      onChanged: (value) => Navigator.of(context).pop(value),
      child: SimpleDialog(
        title: Text(l10n.changeRole),
        children: [
          for (final role in roles)
            RadioListTile<ChatRole>(
              value: role,
              title: Text(chatRoleLabel(role, l10n)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x6,
              AppSpacing.x2,
              AppSpacing.x6,
              0,
            ),
            child: Text(
              isOwner ? l10n.roleOwnerTransferHint : l10n.roleAssignHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BanRequest {
  const _BanRequest({this.reason, this.bannedTo});

  final String? reason;
  final DateTime? bannedTo;
}

class _BanDialog extends StatefulWidget {
  const _BanDialog();

  @override
  State<_BanDialog> createState() => _BanDialogState();
}

class _BanDialogState extends State<_BanDialog> {
  final _reasonController = TextEditingController();

  BanDuration _duration = BanDuration.day;
  DateTime? _until;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();

    return AlertDialog(
      title: Text(l10n.banMemberTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(labelText: l10n.banReason),
            ),
            const SizedBox(height: AppSpacing.x4),
            Text(l10n.banDuration, style: theme.textTheme.labelLarge),
            RadioGroup<BanDuration>(
              groupValue: _duration,
              onChanged: (value) {
                if (value != null) setState(() => _duration = value);
              },
              child: Column(
                children: [
                  for (final option in BanDuration.values)
                    RadioListTile<BanDuration>(
                      value: option,
                      contentPadding: EdgeInsets.zero,
                      title: Text(_durationLabel(l10n, option)),
                      subtitle:
                          option == BanDuration.untilDate && _until != null
                          ? Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatMediumDate(_until!.toLocal()),
                            )
                          : null,
                      secondary: option == BanDuration.untilDate
                          ? TextButton(
                              onPressed: _pickDate,
                              child: Text(l10n.banPickDate),
                            )
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: isBanRequestComplete(_duration, now: now, date: _until)
              ? () => Navigator.of(context).pop(_request(now))
              : null,
          child: Text(l10n.banMember),
        ),
      ],
    );
  }

  String _durationLabel(AppLocalizations l10n, BanDuration duration) =>
      switch (duration) {
        BanDuration.hour => l10n.banForHour,
        BanDuration.day => l10n.banForDay,
        BanDuration.week => l10n.banForWeek,
        BanDuration.forever => l10n.banForever,
        BanDuration.untilDate => l10n.banUntilDate,
      };

  _BanRequest _request(DateTime now) {
    final reason = _reasonController.text.trim();
    return _BanRequest(
      reason: reason.isEmpty ? null : reason,
      bannedTo: banExpiryFor(_duration, now: now, date: _until),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      initialDate: now.add(const Duration(days: 7)),
    );
    if (picked == null) return;

    setState(() {
      _until = picked;
      _duration = BanDuration.untilDate;
    });
  }
}

class _EmptyMembersView extends StatelessWidget {
  const _EmptyMembersView({required this.canInvite, required this.onInvite});

  final bool canInvite;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AppEmptyState(
      icon: Icons.group_outlined,
      title: l10n.membersEmptyTitle,
      message: canInvite ? l10n.membersEmptyInvite : l10n.membersEmptyNoInvite,
      action: canInvite
          ? OutlinedButton.icon(
              onPressed: onInvite,
              icon: const Icon(Icons.person_add_alt),
              label: Text(l10n.addMember),
            )
          : null,
    );
  }
}
