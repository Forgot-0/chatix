import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/utils/debouncer.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/presentation/providers/contact_search_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_list_parts.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The search behind "New message". Its own instance of the contacts
/// search, so typing here never changes what the contacts tab — alive in
/// its own branch — is showing.
final newMessageSearchProvider =
    NotifierProvider.autoDispose<ContactSearchController, ContactSearchState>(
      ContactSearchController.new,
    );

/// The search behind the people step of a new group or channel. Separate
/// from [newMessageSearchProvider]: "New message" stays mounted under it.
final newChatPeopleSearchProvider =
    NotifierProvider.autoDispose<ContactSearchController, ContactSearchState>(
      ContactSearchController.new,
    );

/// A person as the flow carries them, from a row of the book.
NewChatMember newChatMemberOf(Contact contact, AppLocalizations l10n) {
  return NewChatMember(
    userId: contact.userId,
    name: contactNameOf(contact, l10n),
    username: contact.username,
    avatars: contact.profile?.avatars ?? const {},
  );
}

/// …and from somebody the global search found.
NewChatMember newChatMemberOfHit(ContactSearchHit hit, AppLocalizations l10n) {
  final profile = hit.profile;
  final contact = hit.contact;
  if (contact != null) return newChatMemberOf(contact, l10n);
  return NewChatMember(
    userId: hit.userId,
    name: contactProfileNameOf(profile, l10n),
    username: profile?.username,
    avatars: profile?.avatars ?? const {},
  );
}

ChatAvatar newChatMemberAvatar(
  NewChatMember member, {
  ChatAvatarSize size = ChatAvatarSize.md,
  bool? isOnline,
  String? onlineLabel,
}) {
  return ChatAvatar(
    source: member.avatars.isEmpty
        ? AvatarSource.none
        : AvatarSource.variants(member.avatars),
    userId: member.userId,
    name: member.name,
    size: size,
    isOnline: isOnline,
    onlineLabel: onlineLabel,
  );
}

/// The typing half of a people search: the field's text, the pause before
/// the server is asked, and Enter that does not wait for it — the same
/// rhythm as the contacts tab.
mixin PeopleSearchHost<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final TextEditingController searchQuery = TextEditingController();
  final Debouncer _searchDebouncer = Debouncer(ContactsScreen.searchDebounce);

  /// Which search instance this screen drives.
  NotifierProvider<ContactSearchController, ContactSearchState>
  get searchProvider;

  String get _languageCode => Localizations.localeOf(context).languageCode;

  void onSearchChanged(String value) {
    ref
        .read(searchProvider.notifier)
        .setQuery(value, languageCode: _languageCode);
    _searchDebouncer.run(_searchRemote);
    setState(() {});
  }

  void onSearchSubmitted(String _) => _searchDebouncer.runNow(_searchRemote);

  void clearSearch() {
    searchQuery.clear();
    ref.read(searchProvider.notifier).setQuery('', languageCode: _languageCode);
    _searchDebouncer.cancel();
    setState(() {});
  }

  void retrySearch() => _searchRemote();

  void _searchRemote() => ref.read(searchProvider.notifier).searchRemote();

  void disposeSearch() {
    _searchDebouncer.cancel();
    searchQuery.dispose();
  }
}

/// The people under a "new …" screen's header, as one sliver: the book
/// under its letters while nothing is typed, and the two-part search —
/// "my contacts", "global search" — once something is.
class PeopleSliver extends ConsumerWidget {
  const PeopleSliver({
    super.key,
    required this.search,
    required this.rowBuilder,
    required this.onRetry,
    this.emptyBook,
  });

  final ContactSearchState search;

  /// One person's row. [query] is what to pick out of the name.
  final Widget Function(
    BuildContext context,
    NewChatMember member, {
    required String query,
  })
  rowBuilder;

  final VoidCallback onRetry;

  /// What stands in for an empty book.
  final Widget? emptyBook;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return search.isActive ? _results(context) : _book(context, ref);
  }

  Widget _book(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final contacts = ref.watch(contactsProvider);
    final layout = ref.watch(contactListLayoutProvider(languageCode));

    if (contacts.isFirstLoad) {
      return const SliverToBoxAdapter(child: AppListSkeleton(itemCount: 6));
    }
    if (layout.sections.isEmpty) {
      return SliverToBoxAdapter(child: emptyBook ?? const SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: ContactSectionHeader(title: l10n.contacts)),
        for (final section in layout.sections) ...[
          SliverToBoxAdapter(
            child: ContactLetterHeading(letter: section.letter),
          ),
          SliverList.builder(
            itemCount: section.contacts.length,
            itemBuilder: (context, index) => rowBuilder(
              context,
              newChatMemberOf(section.contacts[index], l10n),
              query: '',
            ),
          ),
        ],
      ],
    );
  }

  Widget _results(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = search.query.trim();
    final failure = search.failure;
    final needle = ContactSearchQuery.stripAt(query);

    // Nothing was sent for a query this short, and nothing will be.
    final tooShort =
        !ContactSearchQuery.isUsername(query) &&
        query.length < GetProfilesUseCase.minQueryLength;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: ContactSectionHeader(title: l10n.contactsSectionMine),
        ),
        if (search.mine.isEmpty)
          SliverToBoxAdapter(
            child: PeopleNote(text: l10n.contactsSearchNothingMine),
          )
        else
          SliverList.builder(
            itemCount: search.mine.length,
            itemBuilder: (context, index) => rowBuilder(
              context,
              newChatMemberOf(search.mine[index], l10n),
              query: needle,
            ),
          ),
        SliverToBoxAdapter(
          child: ContactSectionHeader(title: l10n.contactsSectionGlobal),
        ),
        if (search.global.isNotEmpty)
          SliverList.builder(
            itemCount: search.global.length,
            itemBuilder: (context, index) => rowBuilder(
              context,
              newChatMemberOfHit(search.global[index], l10n),
              query: needle,
            ),
          )
        else if (search.isLoading)
          const SliverToBoxAdapter(child: _Searching())
        else if (failure != null)
          SliverToBoxAdapter(
            child: AppInlineError(error: failure, onRetry: onRetry),
          )
        else
          SliverToBoxAdapter(
            child: PeopleNote(
              text: tooShort
                  ? l10n.contactsSearchGlobalHint
                  : l10n.contactsSearchNothingGlobal,
            ),
          ),
      ],
    );
  }
}

/// A person in one of the "new …" lists: face, name, "online" or the
/// handle, and whatever the screen puts at the end.
///
/// Asks for presence the way a contact row does — only someone with a
/// direct chat can be shown as online (api-docs §5.3).
class PersonPickRow extends ConsumerStatefulWidget {
  const PersonPickRow({
    super.key,
    required this.member,
    required this.onTap,
    this.query = '',
    this.trailing,
  });

  final NewChatMember member;
  final VoidCallback onTap;
  final String query;
  final Widget? trailing;

  @override
  ConsumerState<PersonPickRow> createState() => _PersonPickRowState();
}

class _PersonPickRowState extends ConsumerState<PersonPickRow> {
  @override
  void initState() {
    super.initState();
    _requestPresence();
  }

  @override
  void didUpdateWidget(covariant PersonPickRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.member.userId != widget.member.userId) _requestPresence();
  }

  void _requestPresence() {
    final chatId = ref.read(directChatIdsProvider)[widget.member.userId];
    if (chatId != null) {
      ref.read(chatPresenceProvider.notifier).ensureFresh(chatId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final member = widget.member;
    final isOnline = ref.watch(contactOnlineProvider(member.userId));

    // The handle is the title already when there is no other name.
    final handle = member.name == '@${member.username}'
        ? null
        : member.username;

    return PersonRow(
      avatar: newChatMemberAvatar(
        member,
        isOnline: isOnline,
        onlineLabel: l10n.contactsOnline,
      ),
      name: member.name,
      query: widget.query,
      subtitle: isOnline == true
          ? PersonRowSubtitle.online(l10n.contactsOnline)
          : PersonRowSubtitle.handle(handle),
      onTap: widget.onTap,
      trailing: widget.trailing,
    );
  }
}

/// The round tick at the end of a pickable row.
class PickCheck extends StatelessWidget {
  const PickCheck({super.key, required this.selected, this.enabled = true});

  final bool selected;

  /// Dimmed while the picker is full and this one is not in it.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      width: NewChatLayout.checkSize,
      height: NewChatLayout.checkSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? scheme.primary : Colors.transparent,
        border: Border.all(
          color: selected
              ? scheme.primary
              : enabled
              ? scheme.outline
              : scheme.outlineVariant,
          width: NewChatLayout.checkBorder,
        ),
      ),
      child: selected
          ? Icon(
              Icons.check_rounded,
              size: NewChatLayout.checkIcon,
              color: scheme.onPrimary,
            )
          : null,
    );
  }
}

/// The people picked so far as chips, and the search field after them —
/// one box, as in Telegram's "Add members". A tap on a chip takes that
/// person out.
class PickedPeopleBox extends StatefulWidget {
  const PickedPeopleBox({
    super.key,
    required this.members,
    required this.onRemove,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    this.enabled = true,
  });

  final List<NewChatMember> members;
  final ValueChanged<NewChatMember> onRemove;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool enabled;

  @override
  State<PickedPeopleBox> createState() => _PickedPeopleBoxState();
}

class _PickedPeopleBoxState extends State<PickedPeopleBox> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant PickedPeopleBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Someone new goes at the end: keep the end — and the field — in view.
    if (widget.members.length > oldWidget.members.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppMotion.base,
          curve: AppMotion.curve,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: NewChatLayout.chipsMaxHeight,
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x4,
          AppSpacing.x2,
        ),
        child: Wrap(
          spacing: AppSpacing.x2 - 2,
          runSpacing: AppSpacing.x2 - 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final member in widget.members)
              _PickedChip(
                key: ValueKey<int>(member.userId),
                member: member,
                onTap: widget.enabled ? () => widget.onRemove(member) : null,
              ),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: NewChatLayout.inlineFieldMinWidth,
              ),
              child: IntrinsicWidth(
                child: TextField(
                  controller: widget.controller,
                  enabled: widget.enabled,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                  autocorrect: false,
                  style: theme.textTheme.bodyLarge,
                  decoration: InputDecoration(
                    hintText: l10n.searchPeopleHint,
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.x2,
                    ),
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickedChip extends StatelessWidget {
  const _PickedChip({super.key, required this.member, required this.onTap});

  final NewChatMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      button: true,
      label: l10n.newChatRemoveMember(member.name),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: scheme.secondaryContainer,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: NewChatLayout.chipHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.x1,
                end: AppSpacing.x2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  newChatMemberAvatar(member, size: ChatAvatarSize.xxs),
                  const SizedBox(width: AppSpacing.x2 - 2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: NewChatLayout.chipNameMaxWidth,
                    ),
                    child: Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x1),
                  Icon(
                    Icons.close_rounded,
                    size: NewChatLayout.chipCloseIcon,
                    color: scheme.onSecondaryContainer,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet sentence in a list: "nobody found", "type two letters".
class PeopleNote extends StatelessWidget {
  const PeopleNote({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Searching extends StatelessWidget {
  const _Searching();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.x4),
      child: Center(
        child: SizedBox.square(
          dimension: AppSpacing.x5,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
