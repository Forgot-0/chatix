import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/utils/sliding_window_rate_limiter.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// What the search box has found so far.
class ContactSearchState extends Equatable {
  const ContactSearchState({
    this.query = '',
    this.mine = const <Contact>[],
    this.global = const <ContactSearchHit>[],
    this.isLoading = false,
    this.failure,
  });

  final String query;

  /// "My contacts": the book on this device, filtered on every keystroke,
  /// plus whatever the server's prefix search knows that this copy does not.
  final List<Contact> mine;

  /// "Global search": people outside the book — the exact `@username` hit
  /// and the `GET /profiles/?q=` matches.
  final List<ContactSearchHit> global;

  /// A server search is waiting or on the wire.
  final bool isLoading;

  /// Why the server search could not answer; the local half still did.
  final Failure? failure;

  bool get isActive => query.trim().isNotEmpty;

  ContactSearchState copyWith({
    List<Contact>? mine,
    List<ContactSearchHit>? global,
    bool? isLoading,
    Failure? Function()? failure,
  }) {
    return ContactSearchState(
      query: query,
      mine: mine ?? this.mine,
      global: global ?? this.global,
      isLoading: isLoading ?? this.isLoading,
      failure: failure == null ? this.failure : failure(),
    );
  }

  @override
  List<Object?> get props => [query, mine, global, isLoading, failure];
}

/// Keeps the people search within `GET /profiles/`'s 20 requests a minute
/// (api-docs §4.2), shared by every search on the screen.
final profileSearchLimiterProvider = Provider<SlidingWindowRateLimiter>(
  (ref) => SlidingWindowRateLimiter(
    capacity: 20,
    window: const Duration(seconds: 60),
  ),
);

/// The two-part search of the contacts tab.
///
/// [setQuery] answers from the book on this device straight away; the
/// screen calls [searchRemote] once typing has paused, and the server's
/// answers are laid over the local ones — `GET /contacts/search/` for the
/// book and `@username`, `GET /profiles/?q=` for everybody else
/// (api-docs §4.12, §4.2).
class ContactSearchController extends Notifier<ContactSearchState> {
  /// Bumped by every new query, so an answer to an older one is dropped.
  int _generation = 0;
  RequestCancellation? _inFlight;

  @override
  ContactSearchState build() {
    ref.onDispose(() => _inFlight?.cancel());
    return const ContactSearchState();
  }

  /// What the box says now. Local matches are immediate; the server search
  /// is marked as coming when [searchRemote] would have something to send.
  void setQuery(String query, {required String languageCode}) {
    if (query == state.query) return;

    _generation++;
    _inFlight?.cancel();
    _inFlight = null;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = ContactSearchState(query: query);
      return;
    }

    final book = ref.read(contactsProvider).book;
    state = ContactSearchState(
      query: query,
      mine: book.search(trimmed, languageCode: languageCode),
      isLoading: _sendsAnything(trimmed),
    );
  }

  Future<void> searchRemote() async {
    final query = state.query.trim();
    if (!_sendsAnything(query)) return;

    final generation = _generation;
    final cancellation = RequestCancellation();
    _inFlight = cancellation;

    if (!state.isLoading) state = state.copyWith(isLoading: true);

    final (contactsResult, profilesResult) = await (
      ref
          .read(searchContactsUseCaseProvider)
          .execute(query, cancellation: cancellation),
      _searchProfiles(query, cancellation),
    ).wait;

    if (!ref.mounted || generation != _generation) return;
    _inFlight = null;

    final myId = ref.read(authProvider).value?.id;
    final book = ref.read(contactsProvider).book;

    final hits = contactsResult.getOrElse((_) => const <ContactSearchHit>[]);
    final profiles = profilesResult.getOrElse((_) => const <ProfileEntity>[]);

    // The server's prefix search covers the whole book, this device's copy
    // only what it last synced: anybody it found that the copy lacks still
    // belongs under "my contacts".
    final mine = [...state.mine];
    final mineIds = {for (final contact in mine) contact.userId};
    for (final hit in hits) {
      final contact = hit.contact ?? book[hit.userId];
      if (contact == null || !mineIds.add(hit.userId)) continue;
      mine.add(contact);
    }

    bool outside(int userId) =>
        userId != myId && !mineIds.contains(userId) && !book.contains(userId);

    final seen = <int>{};
    final global = <ContactSearchHit>[
      // The exact `@username` hit first: it is the one that was asked for.
      for (final hit in hits)
        if (hit.contact == null && outside(hit.userId) && seen.add(hit.userId))
          hit,
      for (final profile in profiles)
        if (outside(profile.id) && seen.add(profile.id))
          ContactSearchHit(
            userId: profile.id,
            profile: ContactProfile(
              id: profile.id,
              username: profile.username,
              displayName: profile.displayName,
              avatars: profile.avatars,
            ),
          ),
    ];

    final failures = [
      ?contactsResult.getLeft().toNullable(),
      ?profilesResult.getLeft().toNullable(),
    ].where((failure) => failure is! CancelledFailure);

    state = state.copyWith(
      mine: mine,
      global: global,
      isLoading: false,
      // Shown only when nothing came back at all; one half answering is
      // an answer.
      failure: () =>
          global.isEmpty && failures.isNotEmpty ? failures.first : null,
    );
  }

  Future<Either<Failure, List<ProfileEntity>>> _searchProfiles(
    String query,
    RequestCancellation cancellation,
  ) async {
    final needle = ContactSearchQuery.stripAt(query);
    if (needle.length < GetProfilesUseCase.minQueryLength) {
      return const Right(<ProfileEntity>[]);
    }

    final limiter = ref.read(profileSearchLimiterProvider);
    final now = DateTime.now();
    if (limiter.delayFor(now) > Duration.zero) {
      return const Left(RateLimitFailure());
    }
    limiter.record(now);

    final result = await ref
        .read(getProfilesUseCaseProvider)
        .execute(q: needle, pageSize: 20, cancellation: cancellation);

    return result.match((failure) {
      if (failure is RateLimitFailure) limiter.blockFor(DateTime.now());
      return Left(failure);
    }, (page) => Right(page.items));
  }

  /// Whether either server search would send a request for [query].
  static bool _sendsAnything(String query) =>
      ContactSearchQuery.isSearchable(query) ||
      ContactSearchQuery.stripAt(query).length >=
          GetProfilesUseCase.minQueryLength;
}

final contactSearchProvider =
    NotifierProvider.autoDispose<ContactSearchController, ContactSearchState>(
      ContactSearchController.new,
    );
