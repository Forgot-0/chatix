import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Who put which emoji on one message.
///
/// One tab per emoji on the message, opening on the one that was long-pressed.
/// Each tab pages `GET .../reactions/?emoji=…&cursor_user_id=…` on its own —
/// that endpoint is the only way past the three ids a message carries inline
/// (api-docs §5.7.3), and the emoji goes into the query URL-encoded, which
/// dio does on our behalf.
class ReactionUsersSheet extends StatefulWidget {
  const ReactionUsersSheet({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.emoji,
    required this.groups,
    required this.members,
  });

  /// Opens the sheet over the conversation, on the tab for [emoji].
  static Future<void> show(
    BuildContext context, {
    required String chatId,
    required String messageId,
    required String emoji,
    required List<ReactionGroupEntity> groups,
    required List<ChatMemberEntity> members,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => ReactionUsersSheet(
        chatId: chatId,
        messageId: messageId,
        emoji: emoji,
        groups: groups,
        members: members,
      ),
    );
  }

  final String chatId;
  final String messageId;

  /// The tab to open on.
  final String emoji;

  /// Every group on the message, in the server's order (count desc, emoji
  /// asc). One tab each.
  final List<ReactionGroupEntity> groups;

  /// The roster, for names and faces. Anyone missing from it is drawn by id
  /// rather than not at all — the endpoint answers with user ids only.
  final List<ChatMemberEntity> members;

  @override
  State<ReactionUsersSheet> createState() => ReactionUsersSheetState();
}

class ReactionUsersSheetState extends State<ReactionUsersSheet>
    with TickerProviderStateMixin {
  late List<ReactionGroupEntity> _tabs;
  late TabController _controller;

  @override
  void initState() {
    super.initState();

    // A chip was long-pressed, so there is at least one group; a snapshot
    // that arrived while the sheet was opening could still leave the pressed
    // emoji out, and a tab for it is better than an empty sheet.
    _tabs = widget.groups.isEmpty
        ? [ReactionGroupEntity(emoji: widget.emoji, count: 0)]
        : widget.groups;

    final initial = _tabs.indexWhere((g) => g.emoji == widget.emoji);
    _controller = TabController(
      length: _tabs.length,
      initialIndex: initial < 0 ? 0 : initial,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final byId = {for (final member in widget.members) member.userId: member};

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                0,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppLocalizations.of(context).reactedTitle,
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ),
            if (_tabs.length > 1)
              TabBar(
                controller: _controller,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  for (final group in _tabs)
                    Tab(
                      height: 44,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(group.emoji, style: theme.textTheme.titleMedium),
                          const SizedBox(width: AppSpacing.x1),
                          Text(
                            '${group.count}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            Expanded(
              child: TabBarView(
                controller: _controller,
                children: [
                  for (final group in _tabs)
                    ReactionUsersList(
                      key: ValueKey(group.emoji),
                      chatId: widget.chatId,
                      messageId: widget.messageId,
                      emoji: group.emoji,
                      members: byId,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One emoji's worth of people, paged.
class ReactionUsersList extends ConsumerStatefulWidget {
  const ReactionUsersList({
    super.key,
    required this.chatId,
    required this.messageId,
    required this.emoji,
    required this.members,
  });

  final String chatId;
  final String messageId;
  final String emoji;
  final Map<int, ChatMemberEntity> members;

  @override
  ConsumerState<ReactionUsersList> createState() => _ReactionUsersListState();
}

class _ReactionUsersListState extends ConsumerState<ReactionUsersList> {
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_error != null && _users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x3),
            TextButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }

    if (_isLoading && _users.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.x8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Center(child: Text(l10n.reactionsNobody)),
      );
    }

    return ListView.builder(
      itemCount: _users.length + (_hasNext ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _users.length) {
          if (_isLoading) return const AppLoadMoreIndicator();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
            child: Center(
              child: TextButton(onPressed: _load, child: Text(l10n.showMore)),
            ),
          );
        }

        final userId = _users[index];
        final member = widget.members[userId];

        return ListTile(
          leading: ChatAvatar.profile(member?.profile, userId: userId),
          title: Text(
            member?.displayLabel ?? l10n.reactionUserFallback(userId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            widget.emoji,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }
}
