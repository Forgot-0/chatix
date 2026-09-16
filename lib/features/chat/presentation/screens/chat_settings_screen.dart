import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_settings_draft.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about a chat that `PATCH /chats/{chat_id}/` can change.
///
/// Only reachable with `chat:update`; the profile screen hides the way in
/// otherwise, and this screen says so again rather than showing a form that
/// cannot be saved.
class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slowModeController = TextEditingController();

  /// The chat the form was filled from. Its own field rather than a flag so
  /// a refresh that brings genuinely new values re-seeds, and a rebuild that
  /// brings the same ones does not wipe what is half-typed.
  ChatEntity? _seededFrom;

  bool _isPublic = false;
  bool _adminOnly = false;
  ChatReactionsMode _reactionsMode = ChatReactionsMode.all;
  Set<String> _allowedReactions = const {};

  bool _isSaving = false;

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
    _allowedReactions = chat.allowedReactions.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detail = ref.watch(chatDetailProvider(widget.chatId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatSettings)),
      body: detail.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.chatLoadFailed,
          onRetry: () =>
              ref.read(chatDetailProvider(widget.chatId).notifier).refresh(),
        ),
        data: (state) {
          final chat = state.chat;
          if (chat == null) {
            return AppEmptyState(title: l10n.chatLoadFailed);
          }

          if (!hasChatPermission(chat, state.me, ChatPermissions.chatUpdate)) {
            return AppEmptyState(
              icon: Icons.lock_outline,
              title: l10n.chatSettingsNoPermission,
            );
          }

          _seed(chat);

          return ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: _form(l10n, chat),
          );
        },
      ),
    );
  }

  List<Widget> _form(AppLocalizations l10n, ChatEntity chat) {
    final theme = Theme.of(context);

    return [
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.chatName,
            border: const OutlineInputBorder(),
            // The field cannot be emptied once it holds something: the API
            // has no way to unset a name (api-docs §5.2).
            helperText: chat.name == null ? null : l10n.chatNameCannotBeCleared,
          ),
          maxLength: CreateChatUseCase.maxNameLength,
          textInputAction: TextInputAction.next,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: l10n.chatDescription,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          maxLines: 3,
          maxLength: CreateChatUseCase.maxDescriptionLength,
        ),
      ),

      SwitchListTile(
        title: Text(l10n.chatPublic),
        subtitle: Text(l10n.chatPublicHint),
        value: _isPublic,
        onChanged: (value) => setState(() => _isPublic = value),
      ),
      SwitchListTile(
        title: Text(l10n.chatAdminOnly),
        subtitle: Text(l10n.chatAdminOnlyHint),
        value: _adminOnly,
        onChanged: (value) => setState(() => _adminOnly = value),
      ),

      const Divider(height: 24),

      _SectionLabel(l10n.chatSlowMode),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _slowModeController,
          decoration: InputDecoration(
            labelText: l10n.chatSlowModeSecondsField,
            border: const OutlineInputBorder(),
            helperText: l10n.chatSlowModeRange(
              CreateChatUseCase.maxSlowModeSeconds,
            ),
          ),
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (_) => setState(() {}),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Wrap(
          spacing: 8,
          children: [
            for (final preset in const [0, 10, 30, 60, 300, 3600])
              ChoiceChip(
                label: Text(
                  preset == 0
                      ? l10n.chatSlowModeOff
                      : l10n.chatSlowModeSeconds(preset),
                ),
                selected: int.tryParse(_slowModeController.text) == preset,
                onSelected: (_) => setState(
                  () => _slowModeController.text = '$preset',
                ),
              ),
          ],
        ),
      ),

      const Divider(height: 24),

      _SectionLabel(l10n.chatReactionsMode),
      RadioGroup<ChatReactionsMode>(
        groupValue: _reactionsMode,
        onChanged: (value) => setState(
          () => _reactionsMode = value ?? _reactionsMode,
        ),
        child: Column(
          children: [
            for (final mode in ChatReactionsMode.values)
              RadioListTile<ChatReactionsMode>(
                value: mode,
                title: Text(_reactionsLabel(l10n, mode)),
              ),
          ],
        ),
      ),
      if (_reactionsMode == ChatReactionsMode.some) ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.chatReactionsPickHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final emoji in ReactionCatalog.all)
                FilterChip(
                  label: Text(emoji, style: const TextStyle(fontSize: 18)),
                  labelPadding: EdgeInsets.zero,
                  selected: _allowedReactions.contains(emoji),
                  onSelected: (selected) => setState(() {
                    final next = {..._allowedReactions};
                    if (selected) {
                      next.add(emoji);
                    } else {
                      next.remove(emoji);
                    }
                    _allowedReactions = next;
                  }),
                ),
            ],
          ),
        ),
      ],

      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: FilledButton(
          onPressed: _isSaving ? null : () => _save(chat),
          child: _isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.saveChanges),
        ),
      ),
    ];
  }

  String _reactionsLabel(AppLocalizations l10n, ChatReactionsMode mode) {
    return switch (mode) {
      ChatReactionsMode.all => l10n.chatReactionsAll,
      ChatReactionsMode.some => l10n.chatReactionsSome,
      ChatReactionsMode.none => l10n.chatReactionsNone,
    };
  }

  ChatSettingsDraft get _draft => ChatSettingsDraft(
    name: _nameController.text,
    description: _descriptionController.text,
    isPublic: _isPublic,
    adminOnly: _adminOnly,
    slowMode: _slowModeController.text,
    reactionsMode: _reactionsMode,
    allowedReactions: _allowedReactions,
  );

  /// Sends exactly what changed, and nothing else.
  ///
  /// `PATCH /chats/{chat_id}/` is a real partial update — a field absent
  /// from the body stays as it was — so every unchanged control is left out
  /// rather than echoed back (api-docs §5.2).
  Future<void> _save(ChatEntity chat) async {
    final l10n = AppLocalizations.of(context);
    final draft = _draft;

    final problem = draft.validate(chat);
    if (problem != null) {
      _toast(_errorMessage(l10n, problem));
      return;
    }

    final patch = draft.diff(chat);
    if (patch.isEmpty) {
      _toast(l10n.chatSettingsUnchanged);
      return;
    }

    final result = await _run(
      () => ref
          .read(updateChatUseCaseProvider)
          .execute(
            widget.chatId,
            name: patch.name,
            description: patch.description,
            isPublic: patch.isPublic,
            adminOnly: patch.adminOnly,
            slowModeSeconds: patch.slowModeSeconds,
            reactionsMode: patch.reactionsMode,
            allowedReactions: patch.allowedReactions,
          ),
    );
    if (result == null || !mounted) return;

    result.match(
      (failure) => _toast(
        chatFailureMessage(failure) ??
            friendlyFailureMessage(failure, fallback: l10n.saveChangesFailed),
      ),
      (_) {
        _seededFrom = null;
        ref.read(chatDetailProvider(widget.chatId).notifier).refresh();
        ref.read(chatListProvider.notifier).refresh();
        _toast(l10n.chatSettingsSaved);
      },
    );
  }

  String _errorMessage(AppLocalizations l10n, ChatSettingsError problem) {
    return switch (problem) {
      ChatSettingsError.nameCleared => l10n.chatNameCannotBeCleared,
      ChatSettingsError.slowModeOutOfRange => l10n.chatSlowModeRange(
        CreateChatUseCase.maxSlowModeSeconds,
      ),
      ChatSettingsError.noReactionsPicked => l10n.chatReactionsPickHint,
    };
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    setState(() => _isSaving = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
