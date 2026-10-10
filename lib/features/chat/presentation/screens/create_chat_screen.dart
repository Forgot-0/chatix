import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/direct_chat_lookup.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class CreateChatScreen extends ConsumerStatefulWidget {
  const CreateChatScreen({super.key, this.initialType});

  /// Wire value of the chat type to open on, from `?type=` — the shell's
  /// long-press shortcut lands straight on "new group" or "new channel".
  /// Anything unrecognised falls back to a direct chat.
  final String? initialType;

  @override
  ConsumerState<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends ConsumerState<CreateChatScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slowModeController = TextEditingController(text: '0');

  final List<ProfileEntity> _selectedMembers = [];

  late ChatType _chatType = ChatType.fromWire(widget.initialType);
  bool _isPublic = false;
  bool _adminOnly = false;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _slowModeController.dispose();
    super.dispose();
  }

  List<int> get _memberIds =>
      _selectedMembers.map((profile) => profile.id).toList();

  void _addMember(ProfileEntity profile) {
    setState(() {
      if (_chatType == ChatType.direct) {
        _selectedMembers
          ..clear()
          ..add(profile);
      } else if (!_selectedMembers.any((p) => p.id == profile.id)) {
        _selectedMembers.add(profile);
      }
      _error = null;
    });
  }

  void _removeMember(ProfileEntity profile) {
    setState(() => _selectedMembers.removeWhere((p) => p.id == profile.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDirect = _chatType == ChatType.direct;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newChat)),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SegmentedButton<ChatType>(
            // The fill already says which is chosen; the tick only takes
            // room, and four Russian labels in a phone's width need it
            // ("Группа" broke in two).
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: ChatType.direct,
                label: Text(l10n.chatTypeDirect),
              ),
              ButtonSegment(
                value: ChatType.group,
                label: Text(l10n.chatTypeGroup),
              ),
              ButtonSegment(
                value: ChatType.supergroup,
                label: Text(l10n.chatTypeSuper),
              ),
              ButtonSegment(
                value: ChatType.channel,
                label: Text(l10n.chatTypeChannel),
              ),
            ],
            selected: {_chatType},
            onSelectionChanged: (selection) =>
                setState(() => _chatType = selection.first),
          ),
          const SizedBox(height: 16),

          if (!isDirect) ...[
            TextField(
              controller: _nameController,
              maxLength: CreateChatUseCase.maxNameLength,
              decoration: InputDecoration(
                labelText: l10n.chatName,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: CreateChatUseCase.maxDescriptionLength,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: l10n.chatDescription,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          MultiUserSearchField(
            selected: _selectedMembers,
            onAdd: _addMember,
            onRemove: _removeMember,
            labelText: isDirect
                ? l10n.createChatDirectSearchLabel
                : l10n.addPeopleSearchLabel,
            helperText: isDirect
                ? l10n.createChatDirectHelper
                : l10n.createChatMembersHelper(
                    CreateChatUseCase.maxInitialMembers,
                  ),
          ),
          const SizedBox(height: 12),

          if (!isDirect) ...[
            SwitchListTile(
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
              title: Text(l10n.chatPublic),
              subtitle: Text(l10n.chatPublicHintCreate),
            ),
            SwitchListTile(
              value: _adminOnly,
              onChanged: (value) => setState(() => _adminOnly = value),
              title: Text(l10n.chatAdminOnly),
              // The same words as the chat's own settings: who may post,
              // not the name of the right that decides it.
              subtitle: Text(l10n.chatAdminOnlyHint),
            ),
            TextField(
              controller: _slowModeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.chatSlowModeSecondsField,
                helperText: l10n.chatSlowModeRange(
                  CreateChatUseCase.maxSlowModeSeconds,
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.createChat),
          ),
        ],
      ),
    );
  }

  /// What the form would be refused for, in the reader's words.
  ///
  /// [CreateChatUseCase] checks the same rules and answers in English — it
  /// guards callers that never came through a form. Asking here first is
  /// what keeps that English off the screen.
  String? _validate(AppLocalizations l10n, List<int> memberIds) {
    if (_chatType == ChatType.direct) {
      if (memberIds.isEmpty) return l10n.createChatDirectNeedsPeer;
      if (memberIds.length > 1) {
        return l10n.createChatDirectTooMany(memberIds.length);
      }
      return null;
    }

    if (_nameController.text.trim().isEmpty) {
      return l10n.createChatNameRequired;
    }
    if (memberIds.length > CreateChatUseCase.maxInitialMembers) {
      return l10n.createChatTooManyMembers(CreateChatUseCase.maxInitialMembers);
    }
    final slowMode = int.tryParse(_slowModeController.text.trim()) ?? 0;
    if (slowMode < 0 || slowMode > CreateChatUseCase.maxSlowModeSeconds) {
      return l10n.chatSlowModeRange(CreateChatUseCase.maxSlowModeSeconds);
    }
    return null;
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final memberIds = _memberIds;

    final invalid = _validate(l10n, memberIds);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    if (_chatType == ChatType.direct) {
      // Dedup before creating: the backend never raises DIRECT_CHAT_EXISTS, so
      // a second create would silently make a duplicate (api-docs §5.2).
      final existing = findDirectChatWith(
        ref.read(chatListProvider).value?.items ?? const [],
        memberIds.single,
        myUserId: ref.read(authProvider).value?.id,
      );
      if (existing != null) {
        context.pushReplacement(ChatDetailRoute(existing.id).location);
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await ref
        .read(createChatUseCaseProvider)
        .execute(
          name: _chatType == ChatType.direct
              ? null
              : _nameController.text.trim(),
          description: _chatType == ChatType.direct
              ? null
              : _descriptionController.text.trim(),
          chatType: _chatType,
          memberIds: memberIds,
          isPublic: _isPublic,
          adminOnly: _adminOnly,
          slowModeSeconds: int.tryParse(_slowModeController.text.trim()) ?? 0,
        );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.match(
      (failure) {
        final existingChatId = existingDirectChatId(failure);
        if (existingChatId != null) {
          ref.read(chatListProvider.notifier).refresh();
          context.pushReplacement(ChatDetailRoute(existingChatId).location);
          return;
        }
        setState(
          () => _error = friendlyFailureMessage(
            failure,
            l10n: l10n,
            fallback: l10n.createChatFailed,
          ),
        );
      },
      (chat) {
        ref.read(chatListProvider.notifier).refresh();
        context.pushReplacement(ChatDetailRoute(chat.id).location);
      },
    );
  }
}
