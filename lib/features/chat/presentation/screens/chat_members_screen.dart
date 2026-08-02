import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/core/error/failure_messages.dart';

/// `GET /chats/{id}/members/` 🔒 (api-docs §6.3) with the moderation actions
/// of the same section.
///
/// ### Button visibility
///
/// Every action is gated by `hasChatPermission`, which resolves the api-docs
/// §9.1 chain **role baseline → chat-level override → member override**, and by
/// `canModerate`, which additionally refuses self-targeting and protects the
/// owner.
///
/// The authoritative merge happens on the backend (`ChatAccessService`); this
/// only decides what to *draw*, from the last data received. So a hidden
/// button is not a security guarantee and a visible one is not a promise —
/// hence every action still surfaces the server's error if it comes back 403.
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

    // Resolved once, from the last data received, and reused by both the empty
    // state and the FAB — `membersState.value` survives a background refresh
    // error, so the button doesn't flicker away on a failed reload.
    final loaded = membersState.value;
    final canInvite =
        loaded != null &&
        hasChatPermission(loaded.chat, loaded.me, ChatPermissions.memberInvite);

    return Scaffold(
      appBar: AppBar(title: const Text('Members')),
      body: membersState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: friendlyFailureMessage(error, fallback: 'Failed to load members'),
          onRetry: () =>
              ref.read(chatMembersProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) {
          final me = state.me;

          if (state.members.isEmpty) {
            return _EmptyMembersView(
              canInvite: canInvite,
              onInvite: _addMember,
              onRefresh: () =>
                  ref.read(chatMembersProvider(widget.chatId).notifier).refresh(),
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
                        // A missing presence entry means "unknown", not
                        // "offline" (api-docs §6.3).
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
    final userId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => const _AddMemberDialog(),
    );
    if (userId == null) return;

    try {
      await ref
          .read(chatMembersProvider(widget.chatId).notifier)
          .addMember(userId);
    } on Failure catch (failure) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
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
    // `canModerate` is the shared precondition: never yourself, never the
    // owner. Each action then needs its own §9.1 permission on top.
    final moderatable = canModerate(me, member);
    final canChangeRole =
        moderatable &&
        hasChatPermission(chat, me, ChatPermissions.roleChange);
    final canBan =
        moderatable && hasChatPermission(chat, me, ChatPermissions.memberBan);
    final canKick =
        moderatable && hasChatPermission(chat, me, ChatPermissions.memberKick);

    final role = member.role;

    return ListTile(
      leading: Stack(
        children: [
          const CircleAvatar(child: Icon(Icons.person_outline)),
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
      title: Text('User #${member.userId}'),
      subtitle: Row(
        children: [
          // An unknown role_id (added to the backend seed after this build)
          // renders as its raw number rather than a wrong label.
          Text(role?.name ?? 'role ${member.roleId}'),
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
            builder: (dialogContext) =>
                _RolePickerDialog(current: member.role),
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
    // `RadioGroup` owns the selected value and the change callback as of
    // Flutter 3.32; the per-tile `groupValue`/`onChanged` pair is deprecated.
    return RadioGroup<ChatRole>(
      groupValue: current,
      onChanged: (value) => Navigator.of(context).pop(value),
      child: SimpleDialog(
        title: const Text('Change role'),
        children: [
          for (final role in ChatRole.values)
            // `direct` (id=4) is assigned automatically to both participants
            // of a 1:1 chat and is meaningless to set by hand (api-docs §9.1),
            // so it isn't offered.
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

/// ⚠️ Sends `banned_to` — the backend field is literally spelled `banned_to`
/// (typo preserved server-side, api-docs §6.3); the data source does the
/// renaming so nothing above it has to know.
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
                      // No date = permanent, which is the backend's behaviour
                      // when `banned_to` is omitted.
                      ? 'Permanent'
                      : 'Until ${_bannedTo!.toLocal()}',
                ),
              ),
              TextButton(
                onPressed: _pickDate,
                child: const Text('Set date'),
              ),
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
      // A ban must end in the future — the use case rejects a past date, so
      // the picker can't offer one.
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      initialDate: now.add(const Duration(days: 7)),
    );
    if (picked != null) setState(() => _bannedTo = picked);
  }
}

class _AddMemberDialog extends StatefulWidget {
  const _AddMemberDialog();

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'User ID',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final userId = int.tryParse(_controller.text.trim());
            if (userId != null) Navigator.of(context).pop(userId);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Shown when the members page came back empty. Wrapped in a scrollable so
/// pull-to-refresh still works — a plain `Center` has no overscroll for
/// `RefreshIndicator` to react to, which would leave the screen with no way
/// back other than navigating away.
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
