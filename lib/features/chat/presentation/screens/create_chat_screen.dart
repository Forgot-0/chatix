import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    final isDirect = _chatType == ChatType.direct;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).newChat)),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          SegmentedButton<ChatType>(
            segments: [
              ButtonSegment(
                value: ChatType.direct,
                label: Text(AppLocalizations.of(context).chatTypeDirect),
              ),
              ButtonSegment(
                value: ChatType.group,
                label: Text(AppLocalizations.of(context).chatTypeGroup),
              ),
              ButtonSegment(
                value: ChatType.supergroup,
                label: Text(AppLocalizations.of(context).chatTypeSuper),
              ),
              ButtonSegment(
                value: ChatType.channel,
                label: Text(AppLocalizations.of(context).chatTypeChannel),
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
                labelText: AppLocalizations.of(context).chatName,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: CreateChatUseCase.maxDescriptionLength,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).chatDescription,
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
                ? 'Who do you want to message?'
                : 'Add people by username',
            helperText: isDirect
                ? 'Pick exactly one person — a direct chat has two members'
                : 'Up to ${CreateChatUseCase.maxInitialMembers} people now; '
                      'you can add more later',
          ),
          const SizedBox(height: 12),

          if (!isDirect) ...[
            SwitchListTile(
              value: _isPublic,
              onChanged: (value) => setState(() => _isPublic = value),
              title: Text(AppLocalizations.of(context).chatPublic),
              subtitle: Text(AppLocalizations.of(context).chatPublicHintCreate),
            ),
            SwitchListTile(
              value: _adminOnly,
              onChanged: (value) => setState(() => _adminOnly = value),
              title: Text(AppLocalizations.of(context).chatAdminOnly),
              subtitle: const Text(
                'Only members with message:send_admin_only may post',
              ),
            ),
            TextField(
              controller: _slowModeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                ).chatSlowModeSecondsField,
                helperText:
                    '0 – ${CreateChatUseCase.maxSlowModeSeconds} (24 hours)',
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
                : Text(AppLocalizations.of(context).createChat),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final memberIds = _memberIds;

    if (_chatType == ChatType.direct && memberIds.length != 1) {
      setState(() {
        _error = memberIds.isEmpty
            ? 'A direct chat needs exactly one other participant — '
                  'search for them by username'
            : 'A direct chat can only have one other participant, but '
                  '${memberIds.length} were selected — pick Group instead';
      });
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
        setState(() => _error = chatFailureMessage(failure) ?? failure.message);
      },
      (chat) {
        ref.read(chatListProvider.notifier).refresh();
        context.pushReplacement(ChatDetailRoute(chat.id).location);
      },
    );
  }
}
