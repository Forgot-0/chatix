import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/chat/presentation/providers/new_chat_provider.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_details_screen.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_people.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_step_scaffold.dart';
import 'package:chatix/features/contacts/presentation/providers/contact_search_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Picking people: the first step of a new group, the last (and optional)
/// step of a new channel.
///
/// The picked are chips at the top — a tap on one takes them out — with the
/// search after them, and the book below with a tick on every row. At most
/// [NewChatDraft.maxMembers] can be picked now, which is what `POST /chats/`
/// takes at once (api-docs §5.2); the line under the chips says so, and
/// says it louder once the limit is reached.
class NewChatPeopleScreen extends ConsumerStatefulWidget {
  const NewChatPeopleScreen({super.key, required this.kind});

  final NewChatKind kind;

  @override
  ConsumerState<NewChatPeopleScreen> createState() =>
      _NewChatPeopleScreenState();
}

class _NewChatPeopleScreenState extends ConsumerState<NewChatPeopleScreen>
    with PeopleSearchHost<NewChatPeopleScreen> {
  @override
  NotifierProvider<ContactSearchController, ContactSearchState>
  get searchProvider => newChatPeopleSearchProvider;

  NotifierProvider<NewChatController, NewChatState> get _flow =>
      newChatProviderOf(widget.kind);

  bool get _isGroup => widget.kind == NewChatKind.group;

  @override
  void dispose() {
    disposeSearch();
    super.dispose();
  }

  void _toggle(NewChatMember member) {
    final draft = ref.read(_flow).draft;
    if (!draft.contains(member.userId) && draft.isFull) {
      AppSnackbar.quiet(
        context,
        AppLocalizations.of(
          context,
        ).newChatMembersLimitReached(NewChatDraft.maxMembers),
      );
      return;
    }

    ref.read(_flow.notifier).toggle(member);
    // A pick ends the search, as in Telegram: the next person is usually
    // somebody else, and the whole book is the place to find them.
    if (searchQuery.text.isNotEmpty) clearSearch();
  }

  Future<void> _next() async {
    if (_isGroup) {
      context.push(NewGroupDetailsRoute.location);
      return;
    }
    await submitNewChat(context, ref, widget.kind);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(_flow);
    final draft = state.draft;
    final search = ref.watch(newChatPeopleSearchProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return NewChatStepScaffold(
      title: _isGroup
          ? l10n.newGroupMembersTitle
          : l10n.newChannelSubscribersTitle,
      subtitle: l10n.newChatMembersCount(
        draft.members.length,
        NewChatDraft.maxMembers,
      ),
      actionLabel: _isGroup ? l10n.next : l10n.create,
      actionIcon: _isGroup ? Icons.arrow_forward_rounded : Icons.check_rounded,
      onAction: _next,
      busy: state.isSubmitting,
      body: AppContentWidth(
        maxWidth: ContactsLayout.maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickedPeopleBox(
              members: draft.members,
              enabled: !state.isSubmitting,
              onRemove: (member) =>
                  ref.read(_flow.notifier).remove(member.userId),
              controller: searchQuery,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                0,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: Text(
                draft.isFull
                    ? l10n.newChatMembersLimitReached(NewChatDraft.maxMembers)
                    : _isGroup
                    ? l10n.newChatMembersLimitHint(NewChatDraft.maxMembers)
                    : l10n.newChannelSubscribersHint(NewChatDraft.maxMembers),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: draft.isFull
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  PeopleSliver(
                    search: search,
                    onRetry: retrySearch,
                    emptyBook: PeopleNote(text: l10n.newChatNoContacts),
                    rowBuilder: (context, member, {required query}) {
                      final picked = draft.contains(member.userId);
                      return Semantics(
                        key: ValueKey<int>(member.userId),
                        selected: picked,
                        child: PersonPickRow(
                          member: member,
                          query: query,
                          onTap: () => _toggle(member),
                          trailing: PickCheck(
                            selected: picked,
                            enabled: picked || !draft.isFull,
                          ),
                        ),
                      );
                    },
                  ),
                  // Room for the round button over the last rows.
                  const SliverToBoxAdapter(
                    child: SizedBox(height: ChatsListLayout.fabClearance),
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
