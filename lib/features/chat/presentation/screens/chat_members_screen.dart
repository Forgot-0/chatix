import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/usecases/add_member_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';

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
      appBar: AppBar(title: const Text('Members')),
      body: membersState.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: 'Failed to load members',
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
              label: const Text('Add member'),
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
    final avatarUrl = member.profile?.avatarUrl;
    final username = member.profile?.username;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            foregroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
            child: const Icon(Icons.person_outline),
          ),
          if (isOnline == true)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
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
                  const PopupMenuItem(
                    value: 'role',
                    child: Text('Change role'),
                  ),
                if (canBan)
                  const PopupMenuItem(value: 'ban', child: Text('Ban')),
                if (canKick)
                  const PopupMenuItem(value: 'kick', child: Text('Kick')),
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
        title: const Text('Change role'),
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

class _BanDialogState extends State<_BanDialog> {
  final _reasonController = TextEditingController();
  DateTime? _bannedTo;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ban member'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              labelText: 'Reason (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _bannedTo == null
                      ? 'Permanent'
                      : 'Until ${_bannedTo!.toLocal()}',
                ),
              ),
              TextButton(onPressed: _pickDate, child: const Text('Set date')),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            _BanRequest(
              reason: _reasonController.text.trim().isEmpty
                  ? null
                  : _reasonController.text.trim(),
              bannedTo: _bannedTo,
            ),
          ),
          child: const Text('Ban'),
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
    if (picked != null) setState(() => _bannedTo = picked);
  }
}

class _AddMemberDialog extends StatelessWidget {
  const _AddMemberDialog({this.excludedUserIds = const {}});

  final Set<int> excludedUserIds;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member'),
      content: SizedBox(
        width: double.maxFinite,
        child: UserSearchField(
          autofocus: true,
          labelText: 'Search by username',
          excludedUserIds: excludedUserIds,
          onSelected: (profile) => Navigator.of(context).pop(profile.id),
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
                label: const Text('Add member'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
