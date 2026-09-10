import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/direct_chat_lookup.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chatix/features/profile/presentation/widgets/user_search_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class ChatSearchScreen extends ConsumerStatefulWidget {
  const ChatSearchScreen({super.key});

  @override
  ConsumerState<ChatSearchScreen> createState() => _ChatSearchScreenState();
}

class _ChatSearchScreenState extends ConsumerState<ChatSearchScreen> {
  final _controller = TextEditingController();

  Timer? _debounce;
  String _query = '';

  List<ProfileEntity> _people = const [];
  bool _isLoadingPeople = false;
  String? _peopleError;

  int _requestId = 0;

  bool _isStartingChat = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    setState(() => _query = query);

    if (query.isEmpty) {
      setState(() {
        _people = const [];
        _isLoadingPeople = false;
        _peopleError = null;
      });
      return;
    }

    setState(() => _isLoadingPeople = true);
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _searchPeople(query),
    );
  }

  Future<void> _searchPeople(String query) async {
    final requestId = ++_requestId;

    final result = await ref
        .read(getProfilesUseCaseProvider)
        .execute(username: query, pageSize: 20);

    if (!mounted || requestId != _requestId) return;

    setState(() {
      _isLoadingPeople = false;
      result.match(
        (failure) {
          _peopleError = friendlyFailureMessage(
            failure,
            fallback: AppLocalizations.of(context).peopleSearchFailed,
          );
          _people = const [];
        },
        (page) {
          _peopleError = null;
          _people = page.items;
        },
      );
    });
  }

  List<ChatEntity> _matchingChats() {
    if (_query.isEmpty) return const [];

    final chats =
        ref.read(chatListProvider).value?.items ?? const <ChatEntity>[];
    final needle = _query.toLowerCase();

    return chats.where((chat) {
      final name = chat.name?.toLowerCase();
      if (name != null && name.contains(needle)) return true;

      final preview = chat.lastMessage?.content?.toLowerCase();
      return preview != null && preview.contains(needle);
    }).toList();
  }

  Future<void> _openDirectChat(ProfileEntity profile) async {
    if (_isStartingChat) return;

    // Dedup before creating: the backend never raises DIRECT_CHAT_EXISTS, so a
    // second create would silently make a duplicate 1:1 chat (api-docs §5.2).
    final existing = findDirectChatWith(
      ref.read(chatListProvider).value?.items ?? const [],
      profile.id,
      myUserId: ref.read(authProvider).value?.id,
    );
    if (existing != null) {
      context.push(ChatDetailRoute(existing.id).location);
      return;
    }

    setState(() => _isStartingChat = true);

    final result = await ref
        .read(createChatUseCaseProvider)
        .execute(chatType: ChatType.direct, memberIds: [profile.id]);

    if (!mounted) return;
    setState(() => _isStartingChat = false);

    result.match(
      (failure) {
        final existingChatId = existingDirectChatId(failure);
        if (existingChatId != null) {
          ref.read(chatListProvider.notifier).refresh();
          context.pushReplacement(ChatDetailRoute(existingChatId).location);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatFailureMessage(failure) ??
                  friendlyFailureMessage(
                    failure,
                    fallback: AppLocalizations.of(context).startChatFailed,
                  ),
            ),
          ),
        );
      },
      (chat) {
        ref.read(chatListProvider.notifier).refresh();
        context.pushReplacement(ChatDetailRoute(chat.id).location);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(chatListProvider);

    final theme = Theme.of(context);
    final chats = _matchingChats();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context).searchChatsAndPeople,
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: AppLocalizations.of(context).clear,
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _query.isEmpty
          ? const _SearchHint()
          : ListView(
              children: [
                if (chats.isNotEmpty) ...[
                  _SectionHeader(
                    title: AppLocalizations.of(context).chats,
                    theme: theme,
                  ),
                  for (final chat in chats)
                    ChatListTile(chat: chat, enableActions: false),
                ],
                _SectionHeader(
                  title: AppLocalizations.of(context).searchPeople,
                  theme: theme,
                ),
                if (_isLoadingPeople)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_peopleError != null)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_peopleError!, textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => _searchPeople(_query),
                          child: Text(AppLocalizations.of(context).retry),
                        ),
                      ],
                    ),
                  )
                else if (_people.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text(AppLocalizations.of(context).noPeopleFound),
                    ),
                  )
                else
                  for (final profile in _people)
                    ListTile(
                      leading: ProfileAvatar(profile: profile, radius: 20),
                      title: Text(profileLabel(profile)),
                      subtitle: profile.specialization == null
                          ? null
                          : Text(profile.specialization!),
                      onTap: _isStartingChat
                          ? null
                          : () => _openDirectChat(profile),
                    ),

                if (chats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
                    child: Text(
                      'Chats are searched among the conversations already '
                      'loaded, by name and last message — not across full '
                      'message history.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.theme});

  final String title;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Search your chats by name, or find people by username.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
