import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/core/utils/debouncer.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/presentation/providers/contact_search_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_actions.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_list_parts.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The address book (`/contacts`, api-docs §4.7–4.13).
///
/// Opens on this device's copy — no spinner when there is one — and brings
/// it up to date behind the scenes. The search box answers from that copy on
/// every keystroke and asks the server once typing pauses for
/// [searchDebounce], under two headings: the owner's contacts, and
/// everybody else.
class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  static const Duration searchDebounce = Duration(milliseconds: 300);

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _query = TextEditingController();
  final _debouncer = Debouncer(ContactsScreen.searchDebounce);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(contactsProvider.notifier).sync();
      _announce(ref.read(contactImportReportProvider));
    });
  }

  @override
  void dispose() {
    _debouncer.cancel();
    _query.dispose();
    super.dispose();
  }

  String get _languageCode => Localizations.localeOf(context).languageCode;

  void _onQueryChanged(String value) {
    ref
        .read(contactSearchProvider.notifier)
        .setQuery(value, languageCode: _languageCode);
    _debouncer.run(_searchRemote);
    setState(() {});
  }

  /// Enter does not wait out the pause.
  void _onSubmitted(String _) => _debouncer.runNow(_searchRemote);

  void _searchRemote() =>
      ref.read(contactSearchProvider.notifier).searchRemote();

  void _clear() {
    _query.clear();
    ref
        .read(contactSearchProvider.notifier)
        .setQuery('', languageCode: _languageCode);
    _debouncer.cancel();
    setState(() {});
  }

  /// A queued import the server finished while — or before — this screen was
  /// up: said once, then forgotten.
  void _announce(ContactImportReport? report) {
    if (report == null) return;
    AppSnackbar.quiet(
      context,
      AppLocalizations.of(
        context,
      ).contactsImportFinished(report.matched, report.pending),
    );
    ref.read(contactImportReportProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final search = ref.watch(contactSearchProvider);

    ref.listen(contactImportReportProvider, (_, report) => _announce(report));

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.contacts),
        actions: [
          IconButton(
            tooltip: l10n.contactsAddAction,
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => ContactActions.addByUsername(context),
          ),
        ],
      ),
      body: AppContentWidth(
        maxWidth: ContactsLayout.maxWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SearchField(
              controller: _query,
              onChanged: _onQueryChanged,
              onSubmitted: _onSubmitted,
              onClear: _clear,
            ),
            Expanded(
              child: search.isActive
                  ? _SearchResults(state: search, onRetry: _searchRemote)
                  : _ContactList(languageCode: _languageCode),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
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
            hintText: l10n.contactsSearchHint,
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

/// The book itself: the three ways in, then favourites, then A to Я.
class _ContactList extends ConsumerWidget {
  const _ContactList({required this.languageCode});

  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(contactsProvider);
    final layout = ref.watch(contactListLayoutProvider(languageCode));

    final rows = <_ListItem>[
      if (layout.favorites.isNotEmpty) ...[
        _HeadingItem(l10n.contactsFavorites),
        for (final contact in layout.favorites)
          _ContactItem(contact, inFavorites: true),
      ],
      for (final section in layout.sections) ...[
        _LetterItem(section.letter),
        for (final contact in section.contacts) _ContactItem(contact),
      ],
    ];

    final failure = state.failure;

    return RefreshIndicator(
      // A pull is someone asking for the truth: the whole list, the only
      // read that also shows what was deleted elsewhere (api-docs §4.8).
      onRefresh: () =>
          ref.read(contactsProvider.notifier).sync(forceFull: true),
      child: CustomScrollView(
        key: const PageStorageKey<String>('contacts-book'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverToBoxAdapter(child: _EntryRows()),
          if (failure != null && !state.isSyncing)
            SliverToBoxAdapter(
              // With a book to show, the failure is a footnote over it;
              // with none, it is the whole answer.
              child: state.isStored
                  ? _SyncFailedBanner(
                      onRetry: () => ref.read(contactsProvider.notifier).sync(),
                    )
                  : AppInlineError(
                      error: failure,
                      fallbackMessage: l10n.contactsSyncFailed,
                      onRetry: () => ref.read(contactsProvider.notifier).sync(),
                    ),
            ),
          if (state.isFirstLoad)
            const SliverFillRemaining(child: AppListSkeleton(itemCount: 6))
          else if (state.isStored && state.book.isEmpty)
            const SliverToBoxAdapter(child: _EmptyBook())
          else
            SliverList.builder(
              itemCount: rows.length,
              itemBuilder: (context, index) => switch (rows[index]) {
                _HeadingItem(:final title) => ContactSectionHeader(
                  title: title,
                ),
                _LetterItem(:final letter) => ContactLetterHeading(
                  letter: letter,
                ),
                _ContactItem(:final contact, :final inFavorites) => ContactTile(
                  key: inFavorites
                      ? ValueKey<String>('favorite-${contact.userId}')
                      : ValueKey<int>(contact.userId),
                  contact: contact,
                ),
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x8)),
        ],
      ),
    );
  }
}

sealed class _ListItem {
  const _ListItem();
}

final class _HeadingItem extends _ListItem {
  const _HeadingItem(this.title);
  final String title;
}

final class _LetterItem extends _ListItem {
  const _LetterItem(this.letter);
  final String letter;
}

final class _ContactItem extends _ListItem {
  const _ContactItem(this.contact, {this.inFavorites = false});
  final Contact contact;

  /// A favourite is listed twice — under the star and under its letter —
  /// and the two rows need keys of their own.
  final bool inFavorites;
}

/// "Add contact", "Invite friends", "Import by email" — accent rows that
/// line up with the people below them.
class _EntryRows extends ConsumerWidget {
  const _EntryRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ContactEntryRow(
          icon: Icons.person_add_alt_1_outlined,
          label: l10n.contactsAddAction,
          onTap: () => ContactActions.addByUsername(context),
        ),
        Builder(
          // Its own context, so the share sheet anchors on this row.
          builder: (rowContext) => ContactEntryRow(
            icon: Icons.ios_share,
            label: l10n.contactsInviteAction,
            onTap: () => ContactActions.invite(rowContext, ref),
          ),
        ),
        ContactEntryRow(
          icon: Icons.alternate_email,
          label: l10n.contactsImportAction,
          onTap: () => ContactActions.import(context),
        ),
      ],
    );
  }
}

/// "Could not update contacts — Retry", one line over a book that is still
/// there to read.
class _SyncFailedBanner extends StatelessWidget {
  const _SyncFailedBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x2,
        AppSpacing.x4,
        0,
      ),
      child: Material(
        // A footnote, like a failed toast: the book under it still reads.
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
            start: AppSpacing.x3,
            end: AppSpacing.x1,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: AppMenuSizes.iconSize,
                color: scheme.error,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  l10n.contactsSyncFailed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton(onPressed: onRetry, child: Text(l10n.retry)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nobody in the book yet: a picture, a sentence, and the way to fix it.
class _EmptyBook extends StatelessWidget {
  const _EmptyBook();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x8,
        AppSpacing.x8,
        AppSpacing.x8,
        AppSpacing.x4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIllustration(kind: AppIllustrationKind.people),
          const SizedBox(height: AppSpacing.x4),
          Text(
            l10n.contactsEmptyTitle,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            l10n.contactsEmptyMessage,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x5),
          FilledButton.icon(
            onPressed: () => ContactActions.addByUsername(context),
            icon: const Icon(Icons.alternate_email),
            label: Text(l10n.contactsEmptyAction),
          ),
        ],
      ),
    );
  }
}

/// The search, under its two headings.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state, required this.onRetry});

  final ContactSearchState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = state.query.trim();
    final failure = state.failure;

    // Nothing was sent for a query this short, and nothing will be.
    final tooShort =
        !ContactSearchQuery.isUsername(query) &&
        query.length < GetProfilesUseCase.minQueryLength;

    return CustomScrollView(
      key: const PageStorageKey<String>('contacts-search'),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: [
        SliverToBoxAdapter(
          child: ContactSectionHeader(title: l10n.contactsSectionMine),
        ),
        if (state.mine.isEmpty)
          SliverToBoxAdapter(child: _Note(text: l10n.contactsSearchNothingMine))
        else
          SliverList.builder(
            itemCount: state.mine.length,
            itemBuilder: (context, index) => ContactTile(
              key: ValueKey<int>(state.mine[index].userId),
              contact: state.mine[index],
              query: ContactSearchQuery.stripAt(query),
              showMessageButton: true,
            ),
          ),
        SliverToBoxAdapter(
          child: ContactSectionHeader(title: l10n.contactsSectionGlobal),
        ),
        if (state.global.isNotEmpty)
          SliverList.builder(
            itemCount: state.global.length,
            itemBuilder: (context, index) => PersonResultTile(
              key: ValueKey<int>(state.global[index].userId),
              hit: state.global[index],
              query: query,
            ),
          )
        else if (state.isLoading)
          const SliverToBoxAdapter(child: _Searching())
        else if (failure != null)
          SliverToBoxAdapter(
            child: AppInlineError(error: failure, onRetry: onRetry),
          )
        else
          SliverToBoxAdapter(
            child: _Note(
              text: tooShort
                  ? l10n.contactsSearchGlobalHint
                  : l10n.contactsSearchNothingGlobal,
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x8)),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text});

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
