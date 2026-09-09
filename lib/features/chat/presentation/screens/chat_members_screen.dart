import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/usecases/add_member_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class ChatMembersScreen extends ConsumerStatefulWidget {
  const ChatMembersScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatMembersScreen> createState() => _ChatMembersScreenState();
}

class _ChatMembersScreenState extends ConsumerState<ChatMembersScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMembersProvider(widget.chatId).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersState = ref.watch(chatMembersProvider(widget.chatId));

    final loaded = membersState.value;
    final canInvite =
        loaded != null &&
        hasChatPermission(loaded.chat, loaded.me, ChatPermissions.memberInvite);

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).membersTitle)),
      body: membersState.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: AppLocalizations.of(context).membersLoadFailed,
          onRetry: () =>
              ref.read(chatMembersProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) {
          final me = state.me;

          if (state.members.isEmpty) {
            return _EmptyMembersView(
              canInvite: canInvite,
              onInvite: _addMember,
              onRefresh: () => ref
                  .read(chatMembersProvider(widget.chatId).notifier)
                  .refresh(),
            );
          }

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref
                      .read(chatMembersProvider(widget.chatId).notifier)
                      .refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    itemCount:
                        state.members.length + (state.canLoadMore ? 1 : 0),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= state.members.length) {
                        return const AppLoadMoreIndicator();
                      }
                      final member = state.members[index];
                      return _MemberTile(
                        chatId: widget.chatId,
                        chat: state.chat,
                        me: me,
                        member: member,
                        isOnline: state.presence[member.userId],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canInvite
          ? FloatingActionButton.extended(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_alt),
              label: Text(AppLocalizations.of(context).addMember),
            )
          : null,
    );
  }

  Future<void> _addMember() async {
    final loaded = ref.read(chatMembersProvider(widget.chatId)).value;
    final existingIds =
        loaded?.members.map((member) => member.userId).toSet() ?? const <int>{};

    final userId = await showDialog<int>(
      context: context,
      builder: (dialogContext) =>
          _AddMemberDialog(excludedUserIds: existingIds),
    );
    if (userId == null) return;

    try {
      await ref
          .read(chatMembersProvider(widget.chatId).notifier)
          .addMember(userId);
    } on Failure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(addMemberFailureMessage(failure) ?? failure.message),
        ),
      );
    }
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({
    required this.chatId,
    required this.chat,
    required this.me,
    required this.member,
    required this.isOnline,
  });

  final String chatId;
  final ChatEntity? chat;
  final ChatMemberEntity? me;
  final ChatMemberEntity member;
  final bool? isOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moderatable = canModerate(me, member);
    final canChangeRole =
        moderatable && hasChatPermission(chat, me, ChatPermissions.roleChange);
    final canBan =
        moderatable && hasChatPermission(chat, me, ChatPermissions.memberBan);
    final canKick =
        moderatable && hasChatPermission(chat, me, ChatPermissions.memberKick);

    final role = member.role;
    final username = member.profile?.username;

    return ListTile(
      leading: ChatAvatar(
        profile: member.profile,
        userId: member.userId,
        isOnline: isOnline,
      ),
      title: Text(member.displayLabel),
      subtitle: Row(
        children: [
          Text(role?.name ?? 'role ${member.roleId}'),
          if (username != null && username.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text('@$username', overflow: TextOverflow.ellipsis),
            ),
          ],
          if (member.isMuted) ...[
            const SizedBox(width: 8),
            const Icon(Icons.volume_off_outlined, size: 14),
          ],
          if (member.isBanned) ...[
            const SizedBox(width: 8),
            const Icon(Icons.block, size: 14, color: Colors.redAccent),
          ],
        ],
      ),
      trailing: (canChangeRole || canBan || canKick)
          ? PopupMenuButton<String>(
              onSelected: (value) => _onAction(context, ref, value),
              itemBuilder: (menuContext) => [
                if (canChangeRole)
                  PopupMenuItem(
                    value: 'role',
                    child: Text(AppLocalizations.of(context).changeRole),
                  ),
                if (canBan)
                  PopupMenuItem(
                    value: 'ban',
                    child: Text(AppLocalizations.of(context).banMember),
                  ),
                if (canKick)
                  PopupMenuItem(
                    value: 'kick',
                    child: Text(AppLocalizations.of(context).kickMember),
                  ),
              ],
            )
          : null,
    );
  }

  Future<void> _onAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final notifier = ref.read(chatMembersProvider(chatId).notifier);

    try {
      switch (action) {
        case 'role':
          final role = await showDialog<ChatRole>(
            context: context,
            builder: (dialogContext) => _RolePickerDialog(current: member.role),
          );
          if (role == null) return;
          await notifier.changeRole(member.userId, role);

        case 'ban':
          final ban = await showDialog<_BanRequest>(
            context: context,
            builder: (dialogContext) => const _BanDialog(),
          );
          if (ban == null) return;
          await notifier.banMember(
            member.userId,
            reason: ban.reason,
            bannedTo: ban.bannedTo,
          );

        case 'kick':
          await notifier.kickMember(member.userId);
      }
    } on Failure catch (failure) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _RolePickerDialog extends StatelessWidget {
  const _RolePickerDialog({required this.current});

  final ChatRole? current;

  @override
  Widget build(BuildContext context) {
    return RadioGroup<ChatRole>(
      groupValue: current,
      onChanged: (value) => Navigator.of(context).pop(value),
      child: SimpleDialog(
        title: Text(AppLocalizations.of(context).changeRole),
        children: [
          for (final role in ChatRole.values)
            if (role != ChatRole.direct)
              RadioListTile<ChatRole>(value: role, title: Text(role.name)),
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

/// The three shapes `banned_to` can take (api-docs §5.3), spelled out instead
/// of left for the moderator to infer from a date picker:
/// null bans forever, a future date bans until then, a past date lifts the ban.
enum _BanDuration { forever, untilDate, lift }

class _BanDialogState extends State<_BanDialog> {
  final _reasonController = TextEditingController();

  _BanDuration _duration = _BanDuration.forever;
  DateTime? _until;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime? get _bannedTo => switch (_duration) {
    _BanDuration.forever => null,
    _BanDuration.untilDate => _until,
    // Any past instant reads as an unban server-side.
    _BanDuration.lift => DateTime.now().subtract(const Duration(days: 1)),
  };

  bool get _canSubmit => _duration != _BanDuration.untilDate || _until != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

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
            const SizedBox(height: 16),
            Text(l10n.banDuration, style: theme.textTheme.labelLarge),
            RadioGroup<_BanDuration>(
              groupValue: _duration,
              onChanged: (value) {
                if (value != null) setState(() => _duration = value);
              },
              child: Column(
                children: [
                  RadioListTile<_BanDuration>(
                    value: _BanDuration.forever,
                    title: Text(l10n.banForever),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<_BanDuration>(
                    value: _BanDuration.untilDate,
                    title: Text(l10n.banUntilDate),
                    subtitle: _until == null
                        ? null
                        : Text(
                            MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(_until!.toLocal()),
                          ),
                    secondary: TextButton(
                      onPressed: _pickDate,
                      child: Text(l10n.banPickDate),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                  RadioListTile<_BanDuration>(
                    value: _BanDuration.lift,
                    title: Text(l10n.banLift),
                    subtitle: Text(l10n.banLiftHint),
                    contentPadding: EdgeInsets.zero,
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
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(
                  _BanRequest(
                    reason: _reasonController.text.trim().isEmpty
                        ? null
                        : _reasonController.text.trim(),
                    bannedTo: _bannedTo,
                  ),
                )
              : null,
          child: Text(
            _duration == _BanDuration.lift ? l10n.banLift : l10n.banMember,
          ),
        ),
      ],
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
    if (picked != null) {
      setState(() {
        _until = picked;
        _duration = _BanDuration.untilDate;
      });
    }
  }
}

class _AddMemberDialog extends StatelessWidget {
  const _AddMemberDialog({this.excludedUserIds = const {}});

  final Set<int> excludedUserIds;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(AppLocalizations.of(context).addMember),
      content: SizedBox(
        width: double.maxFinite,
        child: UserSearchField(
          autofocus: true,
          labelText: AppLocalizations.of(context).searchByUsername,
          excludedUserIds: excludedUserIds,
          onSelected: (profile) => Navigator.of(context).pop(profile.id),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context).cancel),
        ),
      ],
    );
  }
}

class _EmptyMembersView extends StatelessWidget {
  const _EmptyMembersView({
    required this.canInvite,
    required this.onInvite,
    required this.onRefresh,
  });

  final bool canInvite;
  final VoidCallback onInvite;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 64),
        children: [
          Icon(
            Icons.group_outlined,
            size: 48,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No members to show',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            canInvite
                ? 'Add someone to get this chat started.'
                : 'Only members with the invite permission can add people here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (canInvite) ...[
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: onInvite,
                icon: const Icon(Icons.person_add_alt),
                label: Text(AppLocalizations.of(context).addMember),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
