import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/core/router/app_routes.dart';

/// `POST /chats/` 🔒 4/5min (api-docs §6.2).
///
/// ⚠️ Rate-limited to **4 creations per 5 minutes**, so everything that can be
/// validated offline is: a wasted request costs the user a quarter of their
/// budget. In particular a `direct` chat must carry **exactly one**
/// `member_ids` entry — the other participant — and anything else is caught
/// here (and again in `CreateChatUseCase`) instead of coming back as
/// `400 MEMBER_LIMIT_EXCEEDED`, whose name is actively misleading for the
/// "I selected nobody" case.
///
/// Participants are picked by username through [MultiUserSearchField]
/// (`GET /profiles/?username=`, §4.2) rather than typed as raw numeric ids.
/// The request body is unchanged — it still carries `member_ids: int[]`,
/// derived from [_selectedMembers] — only the way a user finds those ids
/// moved out of their memory and into a search box.
class CreateChatScreen extends ConsumerStatefulWidget {
  const CreateChatScreen({super.key});

  @override
  ConsumerState<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends ConsumerState<CreateChatScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _slowModeController = TextEditingController(text: '0');

  /// People picked in the search field, in pick order.
  ///
  /// The whole profile is kept rather than just the id so the chips can show
  /// a name and avatar; [_memberIds] projects it back down to what the API
  /// takes.
  final List<ProfileEntity> _selectedMembers = [];

  ChatType _chatType = ChatType.direct;
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

  /// `CreateChatRequest.member_ids` — unchanged on the wire.
  List<int> get _memberIds =>
      _selectedMembers.map((profile) => profile.id).toList();

  void _addMember(ProfileEntity profile) {
    setState(() {
      // A direct chat takes exactly one other participant, so a second pick
      // replaces the first instead of producing a selection the submit button
      // would then have to reject.
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
      appBar: AppBar(title: const Text('New chat')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // All four ChatType values are offered — `supergroup` is a distinct
          // type from `group` (different member cap), never a synonym.
          SegmentedButton<ChatType>(
            segments: const [
              ButtonSegment(value: ChatType.direct, label: Text('Direct')),
              ButtonSegment(value: ChatType.group, label: Text('Group')),
              ButtonSegment(value: ChatType.supergroup, label: Text('Super')),
              ButtonSegment(value: ChatType.channel, label: Text('Channel')),
            ],
            selected: {_chatType},
            onSelectionChanged: (selection) =>
                setState(() => _chatType = selection.first),
          ),
          const SizedBox(height: 16),

          // A direct chat has no name/description of its own — it is labelled
          // from the other participant — so those fields are hidden entirely.
          if (!isDirect) ...[
            TextField(
              controller: _nameController,
              maxLength: CreateChatUseCase.maxNameLength,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLength: CreateChatUseCase.maxDescriptionLength,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
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
              title: const Text('Public'),
              subtitle: const Text('Anyone can find and join this chat'),
            ),
            SwitchListTile(
              value: _adminOnly,
              onChanged: (value) => setState(() => _adminOnly = value),
              title: const Text('Admins only'),
              subtitle: const Text(
                'Only members with message:send_admin_only may post',
              ),
            ),
            TextField(
              controller: _slowModeController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Slow mode (seconds)',
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
                : const Text('Create chat'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final memberIds = _memberIds;

    // Client-side guard before spending one of only 4 allowed creations
    // (api-docs §6.2). The use case repeats it; this one is about the message
    // the user sees, phrased for the case they're actually in.
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
        // `409 DIRECT_CHAT_EXISTS` carries the existing chat's id in
        // `detail.chat_id` (api-docs §6.2), so the useful response is to open
        // that conversation rather than to report an error the user can't fix.
        // Shared with the profile screen's "Message" button — see
        // `existingDirectChatId` in create_chat_use_case.dart.
        final existingChatId = existingDirectChatId(failure);
        if (existingChatId != null) {
          ref.read(chatListProvider.notifier).refresh();
          context.pushReplacement(ChatDetailRoute(existingChatId).location);
          return;
        }
        // `SLOW_MODE_OUT_OF_RANGE` / `MEMBER_LIMIT_EXCEEDED` get a phrasing
        // that names the real problem; anything else keeps its own message.
        setState(() => _error = chatFailureMessage(failure) ?? failure.message);
      },
      (chat) {
        ref.read(chatListProvider.notifier).refresh();
        context.pushReplacement(ChatDetailRoute(chat.id).location);
      },
    );
  }
}
