import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/usecases/add_member_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_members_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_actions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_member_roster.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/widgets/member_role_badge.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Picking people out of `GET /profiles/` and adding them to one chat.
///
/// The member limit is enforced here rather than left to the server: every
/// chat type has its own ceiling (api-docs §5.1) and going over it answers
/// `400 MEMBER_LIMIT_EXCEEDED` per person, after some of the batch has
/// already gone through. The screen simply stops accepting names once the
/// room runs out.
class ChatInviteMembersScreen extends ConsumerStatefulWidget {
  const ChatInviteMembersScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatInviteMembersScreen> createState() =>
      _ChatInviteMembersScreenState();
}

class _ChatInviteMembersScreenState
    extends ConsumerState<ChatInviteMembersScreen> {
  final List<ProfileEntity> _selected = [];

  ChatRole? _role;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final membersState = ref.watch(chatMembersProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteMembersTitle)),
      body: membersState.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.membersLoadFailed,
          onRetry: () =>
              ref.read(chatMembersProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) => _body(l10n, state),
      ),
    );
  }

  Widget _body(AppLocalizations l10n, ChatMembersState state) {
    final chat = state.chat;
    final me = state.me;

    if (!hasChatPermission(chat, me, ChatPermissions.memberInvite)) {
      return AppEmptyState(title: l10n.membersEmptyNoInvite);
    }

    final room = remainingMemberSlots(
      chat,
      knownMembers: state.knownMemberCount,
    );
    if (room == 0) {
      return AppEmptyState(
        title: l10n.inviteChatFull(
          chatMemberCapacity(chat?.type ?? ChatType.group),
        ),
      );
    }

    final roles = assignableRolesFor(me);
    final role = _resolvedRole(roles, chat);

    final taken = {
      for (final member in state.members) member.userId,
      for (final member in state.banned) member.userId,
    };

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x2,
            ),
            children: [
              _RoomLeftBanner(room: room),
              const SizedBox(height: AppSpacing.x4),
              MultiUserSearchField(
                selected: _selected,
                excludedUserIds: taken,
                labelText: l10n.searchPeopleHint,
                helperText: _selected.length >= room
                    ? l10n.inviteSelectionFull
                    : l10n.inviteSearchStart,
                onAdd: (profile) => _add(profile, room: room, taken: taken),
                onRemove: (profile) =>
                    setState(() => _selected.remove(profile)),
              ),
              if (roles.length > 1) ...[
                const SizedBox(height: AppSpacing.x6),
                _RolePicker(
                  roles: roles,
                  selected: role,
                  onChanged: (value) => setState(() => _role = value),
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x2,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            child: FilledButton(
              onPressed: _selected.isEmpty || _isSubmitting
                  ? null
                  : () => _submit(role),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.inviteAddSelected(_selected.length)),
            ),
          ),
        ),
      ],
    );
  }

  /// The role new members get: whatever was picked, or the one the server
  /// itself would default to for this kind of chat (api-docs §8.1 — `viewer`
  /// in a channel, `member` everywhere else), narrowed to what this moderator
  /// is allowed to hand out.
  ChatRole _resolvedRole(List<ChatRole> roles, ChatEntity? chat) {
    final picked = _role;
    if (picked != null && roles.contains(picked)) return picked;

    final preferred = chat?.type == ChatType.channel
        ? ChatRole.viewer
        : ChatRole.defaultForNewMember;
    if (roles.contains(preferred)) return preferred;

    return roles.isEmpty ? ChatRole.defaultForNewMember : roles.last;
  }

  void _add(
    ProfileEntity profile, {
    required int room,
    required Set<int> taken,
  }) {
    // Both of these are already filtered out of the search results; the
    // guard is here so a stale result cannot slip one through.
    if (taken.contains(profile.id)) return;
    if (_selected.any((p) => p.id == profile.id)) return;

    if (_selected.length >= room) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).inviteSelectionFull),
        ),
      );
      return;
    }

    setState(() => _selected.add(profile));
  }

  Future<void> _submit(ChatRole role) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _isSubmitting = true);

    final outcome = await ref
        .read(chatMembersProvider(widget.chatId).notifier)
        .addMembers(_selected.map((p) => p.id), role: role);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (outcome.added.isNotEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.inviteAddedCount(outcome.added.length))),
      );
    }

    final failure = outcome.firstFailure;
    if (failure != null) {
      final reason =
          addMemberFailureMessage(failure) ??
          friendlyFailureMessage(failure, fallback: l10n.memberActionFailed);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.inviteFailedCount(outcome.failed.length)} — $reason',
          ),
        ),
      );

      setState(() {
        _selected.removeWhere((p) => outcome.added.contains(p.id));
      });
      return;
    }

    if (context.canPop()) context.pop();
  }
}

class _RoomLeftBanner extends StatelessWidget {
  const _RoomLeftBanner({required this.room});

  final int room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(Icons.groups_outlined, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: AppSpacing.x2),
        Expanded(
          child: Text(
            AppLocalizations.of(context).inviteRoomLeft(room),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.roles,
    required this.selected,
    required this.onChanged,
  });

  final List<ChatRole> roles;
  final ChatRole selected;
  final ValueChanged<ChatRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.inviteRoleLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            for (final role in roles)
              ChoiceChip(
                label: Text(chatRoleLabel(role, l10n)),
                selected: role == selected,
                onSelected: (_) => onChanged(role),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          l10n.roleAssignHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
