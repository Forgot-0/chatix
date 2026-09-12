import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Who put one emoji on one message.
///
/// The list is paged: `GET .../reactions/` is the only way to see past the
/// handful of user ids the message itself carries (api-docs §5.7.3).
class ReactionUsersSheet extends ConsumerStatefulWidget {
  const ReactionUsersSheet({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.emoji,
    required this.members,
  });

  /// Opens the sheet over the conversation.
  static Future<void> show(
    BuildContext context, {
    required String chatId,
    required String messageId,
    required String emoji,
    required List<ChatMemberEntity> members,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ReactionUsersSheet(
        chatId: chatId,
        messageId: messageId,
        emoji: emoji,
        members: members,
      ),
    );
  }

  final String chatId;
  final String messageId;
  final String emoji;

  final List<ChatMemberEntity> members;

  @override
  ConsumerState<ReactionUsersSheet> createState() => ReactionUsersSheetState();
}

class ReactionUsersSheetState extends ConsumerState<ReactionUsersSheet> {
  final _users = <int>[];

  bool _isLoading = true;
  bool _hasNext = false;
  int? _nextUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await ref
        .read(getReactionsUseCaseProvider)
        .executeUsers(
          widget.chatId,
          widget.messageId,
          emoji: widget.emoji,
          cursorUserId: _nextUserId,
        );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      result.match((failure) => _error = failure.message, (page) {
        _users.addAll(page.users);
        _hasNext = page.hasNext;
        _nextUserId = page.nextUserId;
      });
    });
  }

  String _label(int userId) {
    for (final member in widget.members) {
      if (member.userId == userId) return member.displayLabel;
    }
    return 'User #$userId';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(widget.emoji, style: theme.textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context).reactedTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(child: _buildBody(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_error != null && _users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _load,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      );
    }

    if (_isLoading && _users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text(AppLocalizations.of(context).noReactionsYet)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _users.length + (_hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          return _isLoading
              ? const AppLoadMoreIndicator()
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: TextButton(
                      onPressed: _load,
                      child: Text(AppLocalizations.of(context).showMore),
                    ),
                  ),
                );
        }

        final userId = _users[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person_outline)),
          title: Text(_label(userId)),
          trailing: Text(widget.emoji, style: theme.textTheme.titleMedium),
        );
      },
    );
  }
}
