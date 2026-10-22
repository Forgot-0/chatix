import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/supergroup_upgrade_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_permissions.dart';
import 'package:chatix/features/chat/presentation/utils/chat_settings_draft.dart';
import 'package:chatix/features/chat/presentation/utils/slow_mode_presets.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/chat_photo_picker.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about a chat that `PATCH /chats/{chat_id}/` can change, and
/// its picture (api-docs §5.10).
///
/// Only reachable with `chat:update`; the profile screen hides the way in
/// otherwise, and this screen says so again rather than showing a form that
/// cannot be saved.
///
/// Who may post and how often live here rather than in the "new group"
/// flow: they are settings of a chat that exists, not questions to ask
/// before it does. A channel has neither — only its admins post anyway.
class ChatSettingsScreen extends ConsumerStatefulWidget {
  const ChatSettingsScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatSettingsScreen> createState() => _ChatSettingsScreenState();
}

class _ChatSettingsScreenState extends ConsumerState<ChatSettingsScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// The chat the form was filled from. Its own field rather than a flag so
  /// a refresh that brings genuinely new values re-seeds, and a rebuild that
  /// brings the same ones does not wipe what is half-typed.
  ChatEntity? _seededFrom;

  bool _isPublic = false;
  bool _adminOnly = false;
  int _slowModeSeconds = 0;
  ChatReactionsMode _reactionsMode = ChatReactionsMode.all;
  Set<String> _allowedReactions = const {};

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _seed(ChatEntity chat) {
    if (_seededFrom == chat) return;
    _seededFrom = chat;

    _nameController.text = chat.name ?? '';
    _descriptionController.text = chat.description ?? '';
    _slowModeSeconds = chat.slowModeSeconds;
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
              illustration: AppIllustrationKind.locked,
              title: l10n.chatSettingsNoPermission,
            );
          }

          _seed(chat);

          final upgrade = ref.watch(supergroupUpgradeProvider);
          final isOwner = hasChatPermission(
            chat,
            state.me,
            ChatPermissions.chatDelete,
          );

          return AppContentWidth(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.x8),
              children: [
                if (chat.type != ChatType.direct) _ChatPhotoEditor(chat: chat),
                ..._form(l10n, chat),
                if (upgrade != null && isOwner && chat.type == ChatType.group)
                  _SupergroupUpgrade(chat: chat, upgrade: upgrade),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _form(AppLocalizations l10n, ChatEntity chat) {
    final theme = Theme.of(context);
    final isChannel = chat.type == ChatType.channel;

    return [
      const SizedBox(height: AppSpacing.x2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: l10n.chatName,
            // The field cannot be emptied once it holds something: the API
            // has no way to unset a name (api-docs §5.2).
            helperText: chat.name == null ? null : l10n.chatNameCannotBeCleared,
            helperMaxLines: 2,
          ),
          maxLength: CreateChatUseCase.maxNameLength,
          textInputAction: TextInputAction.next,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: l10n.chatDescription,
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
      if (!isChannel)
        SwitchListTile(
          // Who may post, in the reader's words — never the name of the
          // right (`message:send_admin_only`) that decides it.
          title: Text(l10n.chatAdminOnly),
          subtitle: Text(l10n.chatAdminOnlyHint),
          value: _adminOnly,
          onChanged: (value) => setState(() => _adminOnly = value),
        ),

      if (!isChannel) ...[
        const Divider(height: AppSpacing.x6),
        _SectionLabel(l10n.chatSlowMode),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x2,
          ),
          child: Text(
            l10n.chatSlowModeHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Wrap(
            spacing: AppSpacing.x2,
            runSpacing: AppSpacing.x2,
            children: [
              for (final seconds in SlowModePresets.including(
                chat.slowModeSeconds,
              ))
                ChoiceChip(
                  label: Text(slowModeLabel(seconds, l10n)),
                  selected: _slowModeSeconds == seconds,
                  onSelected: (_) =>
                      setState(() => _slowModeSeconds = seconds),
                ),
            ],
          ),
        ),
      ],

      const Divider(height: AppSpacing.x6),

      _SectionLabel(l10n.chatReactionsMode),
      RadioGroup<ChatReactionsMode>(
        groupValue: _reactionsMode,
        onChanged: (value) =>
            setState(() => _reactionsMode = value ?? _reactionsMode),
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
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Text(
            l10n.chatReactionsPickHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
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

      const SizedBox(height: AppSpacing.x2),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
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
    slowMode: '$_slowModeSeconds',
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
            friendlyFailureMessage(
              failure,
              l10n: l10n,
              fallback: l10n.saveChangesFailed,
            ),
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

/// The chat's own picture, big, with the words that change it under it.
///
/// A new picture goes up straight away — it is not part of the form's
/// "Save" — and shows once the server has cut it into sizes and said so
/// with `chat_updated` (api-docs §5.10); until then the reader is told it
/// is on its way.
class _ChatPhotoEditor extends ConsumerStatefulWidget {
  const _ChatPhotoEditor({required this.chat});

  final ChatEntity chat;

  @override
  ConsumerState<_ChatPhotoEditor> createState() => _ChatPhotoEditorState();
}

class _ChatPhotoEditorState extends ConsumerState<_ChatPhotoEditor> {
  bool _busy = false;

  Future<void> _change() async {
    final chat = widget.chat;
    final action = await showChatPhotoSheet(
      context,
      canRemove: chat.hasAvatar,
    );
    if (action == null || !mounted) return;

    final l10n = AppLocalizations.of(context);

    if (action == ChatPhotoAction.remove) {
      setState(() => _busy = true);
      final result = await ref
          .read(removeChatAvatarUseCaseProvider)
          .execute(chat.id);
      if (!mounted) return;
      setState(() => _busy = false);
      result.match(
        (failure) => AppSnackbar.failure(
          context,
          friendlyFailureMessage(
            failure,
            l10n: l10n,
            fallback: l10n.chatPhotoFailed,
          ),
        ),
        (_) {
          ref.read(chatDetailProvider(chat.id).notifier).refresh();
          AppSnackbar.quiet(context, l10n.chatPhotoRemoved);
        },
      );
      return;
    }

    final photo = await ref.read(chatPhotoPickerProvider)(
      context,
      action == ChatPhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (photo == null || !mounted) return;

    setState(() => _busy = true);
    final result = await ref
        .read(uploadChatAvatarUseCaseProvider)
        .execute(chat.id, bytes: photo.bytes, mimeType: photo.mimeType);
    if (!mounted) return;
    setState(() => _busy = false);

    result.match(
      (failure) => AppSnackbar.failure(
        context,
        friendlyFailureMessage(
          failure,
          l10n: l10n,
          fallback: l10n.chatPhotoFailed,
        ),
      ),
      (_) => AppSnackbar.quiet(context, l10n.chatPhotoUploaded),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final chat = widget.chat;
    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x4),
      child: Column(
        children: [
          SizedBox.square(
            dimension: ChatAvatarSize.xl.diameter,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ChatRowAvatar(
                  chat: chat,
                  myUserId: myUserId,
                  size: ChatAvatarSize.xl,
                ),
                if (_busy)
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.mediaScrim,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.x1),
                      child: CircularProgressIndicator(
                        color: AppPalette.onMediaScrim,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          TextButton(
            onPressed: _busy ? null : _change,
            child: Text(chat.hasAvatar ? l10n.changePhoto : l10n.setPhoto),
          ),
        ],
      ),
    );
  }
}

/// "Convert to supergroup", tucked at the end under "Advanced", with what it
/// means said before it happens. Shown only when there is a way to do it
/// ([supergroupUpgradeProvider]) and only to the owner.
class _SupergroupUpgrade extends ConsumerStatefulWidget {
  const _SupergroupUpgrade({required this.chat, required this.upgrade});

  final ChatEntity chat;
  final SupergroupUpgrader upgrade;

  @override
  ConsumerState<_SupergroupUpgrade> createState() => _SupergroupUpgradeState();
}

class _SupergroupUpgradeState extends ConsumerState<_SupergroupUpgrade> {
  bool _busy = false;

  Future<void> _confirmAndUpgrade() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.chatSupergroupTitle),
        content: Text(
          l10n.chatSupergroupConfirm(ChatType.supergroup.maxMembers),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.chatSupergroupAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final result = await widget.upgrade(widget.chat.id);
    if (!mounted) return;
    setState(() => _busy = false);

    result.match(
      (failure) => AppSnackbar.failure(
        context,
        friendlyFailureMessage(
          failure,
          l10n: l10n,
          fallback: l10n.saveChangesFailed,
        ),
      ),
      (_) {
        ref.read(chatDetailProvider(widget.chat.id).notifier).refresh();
        ref.read(chatListProvider.notifier).refresh();
        AppSnackbar.quiet(context, l10n.chatSupergroupDone);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: AppSpacing.x8),
        _SectionLabel(l10n.chatSettingsAdvanced),
        ListTile(
          enabled: !_busy,
          leading: const Icon(Icons.groups_outlined),
          title: Text(l10n.chatSupergroupTitle),
          subtitle: Text(
            l10n.chatSupergroupHint(ChatType.supergroup.maxMembers),
          ),
          trailing: _busy
              ? const SizedBox.square(
                  dimension: AppSpacing.x5,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _confirmAndUpgrade,
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}
