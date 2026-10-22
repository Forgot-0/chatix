import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_people.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_step_scaffold.dart';
import 'package:chatix/features/contacts/presentation/providers/contact_search_provider.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:chatix/features/settings/presentation/utils/privacy_labels.dart';
import 'package:chatix/features/settings/presentation/widgets/privacy_people.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The search behind the exceptions picker — an instance of its own, so it
/// never changes what the contacts tab is showing.
final privacyPeopleSearchProvider =
    NotifierProvider.autoDispose<ContactSearchController, ContactSearchState>(
      ContactSearchController.new,
    );

/// Picking the people on one of a rule's lists, the way people are picked
/// for a new group: chips of the picked on top, the search after them, the
/// book under it with a tick on every row.
///
/// Opens with the list as it stands, so the same screen adds and takes
/// away; "Save" sends the list whole, which is how the server takes it
/// (api-docs §4.14). Somebody picked here leaves the other list of the
/// rule, and the two together stay within [PrivacyExceptions.limit].
class PrivacyPeoplePickerScreen extends ConsumerStatefulWidget {
  const PrivacyPeoplePickerScreen({
    super.key,
    required this.rule,
    required this.kind,
  });

  final PrivacyRule rule;
  final PrivacyExceptionKind kind;

  @override
  ConsumerState<PrivacyPeoplePickerScreen> createState() =>
      _PrivacyPeoplePickerScreenState();
}

class _PrivacyPeoplePickerScreenState
    extends ConsumerState<PrivacyPeoplePickerScreen>
    with PeopleSearchHost<PrivacyPeoplePickerScreen> {
  @override
  NotifierProvider<ContactSearchController, ContactSearchState>
  get searchProvider => privacyPeopleSearchProvider;

  /// Who is on the list, in the order they were put there. Null until the
  /// settings are read.
  List<int>? _picked;

  /// Rows tapped in this visit, so their chips need no lookup.
  final Map<int, NewChatMember> _known = {};

  bool _saving = false;

  @override
  void dispose() {
    disposeSearch();
    super.dispose();
  }

  void _toggle(NewChatMember member, {required int room}) {
    final picked = _picked;
    if (picked == null) return;

    if (picked.contains(member.userId)) {
      setState(() => picked.remove(member.userId));
    } else {
      if (picked.length >= room) {
        AppSnackbar.quiet(
          context,
          AppLocalizations.of(context).privacyExceptionsFull,
        );
        return;
      }
      setState(() {
        picked.add(member.userId);
        _known[member.userId] = member;
      });
    }
    // A pick ends the search, as in Telegram: the next person is usually
    // somebody else, and the whole book is the place to find them.
    if (searchQuery.text.isNotEmpty) clearSearch();
  }

  Future<void> _save() async {
    final picked = _picked;
    final current = ref.read(privacySettingsProvider).value;
    if (picked == null || current == null || _saving) return;

    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final failure = await ref
        .read(privacySettingsProvider.notifier)
        .setExceptions(
          widget.rule,
          current.exceptionsOf(widget.rule).withList(widget.kind, picked),
        );
    if (!mounted) return;
    setState(() => _saving = false);

    if (failure != null) {
      AppSnackbar.failure(
        context,
        friendlyFailureMessage(
          failure,
          l10n: l10n,
          fallback: l10n.privacySaveFailed,
        ),
      );
      return;
    }
    context.pop();
  }

  NewChatMember _memberOf(int userId, AppLocalizations l10n) {
    final known = _known[userId];
    if (known != null) return known;
    final person = watchPrivacyPerson(ref, userId, l10n);
    return person.value ??
        NewChatMember(
          userId: userId,
          name: person.hasError ? l10n.contactsUnknownPerson : l10n.loading,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = ref.watch(privacySettingsProvider).value;

    if (settings == null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.kind.title(l10n))),
        body: const AppListSkeleton(),
      );
    }

    final lists = settings.exceptionsOf(widget.rule);
    final picked = _picked ??= [...lists.of(widget.kind)];
    final room = lists.roomFor(widget.kind);
    final search = ref.watch(privacyPeopleSearchProvider);

    return NewChatStepScaffold(
      title: widget.kind.title(l10n),
      subtitle: l10n.privacyPickerCount(picked.length, room),
      actionLabel: l10n.save,
      actionIcon: Icons.check_rounded,
      onAction: _save,
      busy: _saving,
      body: AppContentWidth(
        maxWidth: ContactsLayout.maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickedPeopleBox(
              members: [for (final id in picked) _memberOf(id, l10n)],
              enabled: !_saving,
              onRemove: (member) =>
                  setState(() => picked.remove(member.userId)),
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
                widget.rule.title(l10n),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
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
                      final isPicked = picked.contains(member.userId);
                      return Semantics(
                        key: ValueKey<int>(member.userId),
                        selected: isPicked,
                        child: PersonPickRow(
                          member: member,
                          query: query,
                          onTap: () => _toggle(member, room: room),
                          trailing: PickCheck(
                            selected: isPicked,
                            enabled: isPicked || picked.length < room,
                          ),
                        ),
                      );
                    },
                  ),
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
