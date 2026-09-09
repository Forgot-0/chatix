import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class ChatInfoScreen extends ConsumerStatefulWidget {
  const ChatInfoScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slowModeController = TextEditingController();

  ChatEntity? _seededFrom;

  bool? _isPublic;
  bool? _adminOnly;
  ChatReactionsMode? _reactionsMode;

  bool _isSaving = false;
  bool _isLeaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _slowModeController.dispose();
    super.dispose();
  }

  void _seed(ChatEntity chat) {
    if (_seededFrom == chat) return;
    _seededFrom = chat;

    _nameController.text = chat.name ?? '';
    _descriptionController.text = chat.description ?? '';
    _slowModeController.text = '${chat.slowModeSeconds}';
    _isPublic = chat.isPublic;
    _adminOnly = chat.adminOnly;
    _reactionsMode = chat.reactionsMode;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(chatDetailProvider(widget.chatId));
    final myUserId = ref.watch(authProvider).value?.id;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatInfo)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.errorOccurred,
          onRetry: () =>
              ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) {
          final chat = state.chat;
          if (chat == null) {
            return Center(child: Text(l10n.errorOccurred));
          }

          _seed(chat);

          final me = state.me;
          final canUpdate = hasChatPermission(
            chat,
            me,
            ChatPermissions.chatUpdate,
          );
          final canDelete = hasChatPermission(
            chat,
            me,
            ChatPermissions.chatDelete,
          );

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _Header(chat: chat, myUserId: myUserId),
              const Divider(height: 24),

              if (canUpdate)
                ..._editableSettings(l10n, chat)
              else
                ..._readOnlySettings(l10n, chat),

              const Divider(height: 24),

              ListTile(
                leading: const Icon(Icons.people_outline),
                title: Text(l10n.viewMembers),
                subtitle: Text(l10n.membersCount(chat.memberCount)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push(ChatMembersRoute.locationOf(widget.chatId)),
              ),

              const Divider(height: 24),

              _leaveTile(l10n, chat, me),
              if (canDelete) _deleteTile(l10n),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _readOnlySettings(AppLocalizations l10n, ChatEntity chat) {
    final description = chat.description?.trim();

    return [
      if (description != null && description.isNotEmpty)
        ListTile(
          title: Text(l10n.chatDescription),
          subtitle: Text(description),
        ),
      ListTile(
        title: Text(l10n.chatSlowMode),
        subtitle: Text(
          chat.slowModeSeconds == 0
              ? l10n.chatSlowModeOff
              : l10n.chatSlowModeSeconds(chat.slowModeSeconds),
        ),
      ),
      ListTile(
        title: Text(l10n.chatReactionsMode),
        subtitle: Text(_reactionsLabel(l10n, chat.reactionsMode)),
      ),
    ];
  }

  List<Widget> _editableSettings(AppLocalizations l10n, ChatEntity chat) {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.chatName,
            border: const OutlineInputBorder(),
          ),
          maxLength: 255,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: l10n.chatDescription,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 1024,
        ),
      ),
      SwitchListTile(
        title: Text(l10n.chatPublic),
        subtitle: Text(l10n.chatPublicHint),
        value: _isPublic ?? chat.isPublic,
        onChanged: (value) => setState(() => _isPublic = value),
      ),
      SwitchListTile(
        title: Text(l10n.chatAdminOnly),
        subtitle: Text(l10n.chatAdminOnlyHint),
        value: _adminOnly ?? chat.adminOnly,
        onChanged: (value) => setState(() => _adminOnly = value),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _slowModeController,
          decoration: InputDecoration(
            labelText: l10n.chatSlowMode,
            border: const OutlineInputBorder(),
            helperText: l10n.chatSlowModeSeconds(0),
          ),
          keyboardType: TextInputType.number,
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            l10n.chatReactionsMode,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
      RadioGroup<ChatReactionsMode>(
        groupValue: _reactionsMode ?? chat.reactionsMode,
        onChanged: (value) => setState(() => _reactionsMode = value),
        child: Column(
          children: [
            for (final mode in const [
              ChatReactionsMode.all,
              ChatReactionsMode.none,
            ])
              RadioListTile<ChatReactionsMode>(
                value: mode,
                title: Text(_reactionsLabel(l10n, mode)),
              ),
            if (chat.reactionsMode == ChatReactionsMode.some)
              RadioListTile<ChatReactionsMode>(
                value: ChatReactionsMode.some,
                title: Text(_reactionsLabel(l10n, ChatReactionsMode.some)),
                subtitle: Text(chat.allowedReactions.join(' ')),
              ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FilledButton(
          onPressed: _isSaving ? null : () => _save(chat),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.saveChanges),
        ),
      ),
    ];
  }

  Widget _leaveTile(
    AppLocalizations l10n,
    ChatEntity chat,
    ChatMemberEntity? me,
  ) {
    final blocked = me != null && !canLeaveChat(chat, me);

    return ListTile(
      leading: Icon(
        Icons.logout,
        color: blocked ? null : Theme.of(context).colorScheme.error,
      ),
      title: Text(l10n.leaveChat),
      subtitle: blocked ? Text(l10n.leaveChatOwnerBlocked) : null,
      enabled: !blocked && !_isLeaving,
      onTap: blocked ? null : _leave,
    );
  }

  Widget _deleteTile(AppLocalizations l10n) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.delete_outline, color: scheme.error),
      title: Text(l10n.deleteChat, style: TextStyle(color: scheme.error)),
      onTap: _isLeaving ? null : _delete,
    );
  }

  String _reactionsLabel(AppLocalizations l10n, ChatReactionsMode mode) {
    switch (mode) {
      case ChatReactionsMode.all:
        return l10n.chatReactionsAll;
      case ChatReactionsMode.some:
        return l10n.chatReactionsSome;
      case ChatReactionsMode.none:
        return l10n.chatReactionsNone;
    }
  }

  Future<void> _save(ChatEntity chat) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final slowMode = int.tryParse(_slowModeController.text.trim());
    final isPublic = _isPublic ?? chat.isPublic;
    final adminOnly = _adminOnly ?? chat.adminOnly;
    final reactionsMode = _reactionsMode ?? chat.reactionsMode;

    final result = await ref
        .read(updateChatUseCaseProvider)
        .execute(
          widget.chatId,
          name: name == (chat.name ?? '') ? null : name,
          description: description == (chat.description ?? '')
              ? null
              : description,
          isPublic: isPublic == chat.isPublic ? null : isPublic,
          adminOnly: adminOnly == chat.adminOnly ? null : adminOnly,
          slowModeSeconds:
              (slowMode == null || slowMode == chat.slowModeSeconds)
              ? null
              : slowMode,
          reactionsMode: reactionsMode == chat.reactionsMode
              ? null
              : reactionsMode,
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    result.match(
      (failure) => _toast(
        chatFailureMessage(failure) ??
            friendlyFailureMessage(failure, fallback: l10n.errorOccurred),
      ),
      (_) {
        _seededFrom = null;
        ref.read(chatDetailProvider(widget.chatId).notifier).refresh();
        ref.read(chatListProvider.notifier).refresh();
        _toast(l10n.chatSettingsSaved);
      },
    );
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

class _Header extends StatelessWidget {
  const _Header({required this.chat, required this.myUserId});

  final ChatEntity chat;
  final int? myUserId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final peer = chat.peerProfile(myUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          if (peer != null)
            ChatAvatar(profile: peer, userId: peer.userId, radius: 40)
          else
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.groups_outlined,
                size: 36,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          const SizedBox(height: 12),
          Text(
            chatTitleOf(chat, l10n, myUserId: myUserId),
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            chatTypeLabel(chat.type, l10n),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
