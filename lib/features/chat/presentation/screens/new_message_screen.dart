import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/direct_chat_opener.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_people.dart';
import 'package:chatix/features/contacts/presentation/providers/contact_search_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_actions.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_list_parts.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// "New message" — where the chats list's pencil leads.
///
/// As in Telegram there is no "direct chat" to choose: a person is the
/// choice. Tapping one opens the chat with them — the one that already
/// exists, wherever it is, or a new one when there truly is none
/// ([DirectChatOpener]). Above the people, the ways into a new group, a new
/// channel and the address book; above those, a search that covers the
/// book on every keystroke and everybody by name or `@username` once typing
/// pauses.
class NewMessageScreen extends ConsumerStatefulWidget {
  const NewMessageScreen({super.key});

  @override
  ConsumerState<NewMessageScreen> createState() => _NewMessageScreenState();
}

class _NewMessageScreenState extends ConsumerState<NewMessageScreen>
    with PeopleSearchHost<NewMessageScreen> {
  /// The person whose chat is being found or made, so the row can say so
  /// and a second tap anywhere waits for it.
  int? _opening;

  @override
  NotifierProvider<ContactSearchController, ContactSearchState>
  get searchProvider => newMessageSearchProvider;

  @override
  void initState() {
    super.initState();
    // Picks up whoever was added on another device since the last sync —
    // a delta, cheap, and the list is already on screen from this device.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(contactsProvider.notifier).sync();
    });
  }

  @override
  void dispose() {
    disposeSearch();
    super.dispose();
  }

  Future<void> _open(NewChatMember member) async {
    if (_opening != null) return;
    setState(() => _opening = member.userId);

    final result = await ref
        .read(directChatOpenerProvider)
        .resolve(member.userId);
    if (!mounted) return;
    setState(() => _opening = null);

    final l10n = AppLocalizations.of(context);
    result.match(
      (failure) {
        if (failure is CancelledFailure) return;
        AppSnackbar.failure(
          context,
          chatFailureMessage(failure) ??
              friendlyFailureMessage(
                failure,
                l10n: l10n,
                fallback: l10n.startChatFailed,
              ),
        );
      },
      // `go`, not `push`: back from the chat is the chats list, not this
      // screen — the choice has been made.
      (chatId) => context.go(ChatDetailRoute(chatId).location),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final search = ref.watch(newMessageSearchProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.newMessage)),
      body: AppContentWidth(
        maxWidth: ContactsLayout.maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NewChatSearchField(
              controller: searchQuery,
              onChanged: onSearchChanged,
              onSubmitted: onSearchSubmitted,
              onClear: clearSearch,
            ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  if (!search.isActive)
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ContactEntryRow(
                            icon: Icons.group_add_outlined,
                            label: l10n.newGroup,
                            onTap: () => context.push(NewGroupRoute.location),
                          ),
                          ContactEntryRow(
                            icon: Icons.campaign_outlined,
                            label: l10n.newChannel,
                            onTap: () => context.push(NewChannelRoute.location),
                          ),
                          ContactEntryRow(
                            icon: Icons.person_add_alt_1_outlined,
                            label: l10n.contactsAddAction,
                            onTap: () => ContactActions.addByUsername(context),
                          ),
                        ],
                      ),
                    ),
                  PeopleSliver(
                    search: search,
                    onRetry: retrySearch,
                    emptyBook: PeopleNote(text: l10n.newMessageNoContacts),
                    rowBuilder: (context, member, {required query}) =>
                        PersonPickRow(
                          key: ValueKey<int>(member.userId),
                          member: member,
                          query: query,
                          onTap: () => _open(member),
                          trailing: _opening == member.userId
                              ? const SizedBox.square(
                                  dimension: AppSpacing.x5,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                        ),
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: AppSpacing.x8),
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

/// The pill search field at the top of "New message" — the contacts tab's
/// own shape, so the two read as the same search.
class NewChatSearchField extends StatelessWidget {
  const NewChatSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.full),
      borderSide: BorderSide.none,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x1,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: SizedBox(
        height: ContactsLayout.searchHeight,
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: l10n.searchPeopleHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clear,
                    icon: const Icon(Icons.close),
                    onPressed: onClear,
                  ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
            ),
            fillColor: scheme.surfaceContainerHigh,
            border: pill,
            enabledBorder: pill,
            focusedBorder: pill.copyWith(
              borderSide: BorderSide(color: scheme.primary, width: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}
