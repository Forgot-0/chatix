import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/data/repositories/contacts_repository_impl.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_book.dart';
import 'package:chatix/features/contacts/domain/entities/contact_collation.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/usecases/contact_use_cases.dart';
import 'package:chatix/features/contacts/domain/usecases/import_contacts_use_case.dart';

final syncContactsUseCaseProvider = Provider<SyncContactsUseCase>(
  (ref) => SyncContactsUseCase(ref.watch(contactsRepositoryProvider)),
);

final saveContactUseCaseProvider = Provider<SaveContactUseCase>(
  (ref) => SaveContactUseCase(ref.watch(contactsRepositoryProvider)),
);

final editContactUseCaseProvider = Provider<EditContactUseCase>(
  (ref) => EditContactUseCase(ref.watch(contactsRepositoryProvider)),
);

final deleteContactUseCaseProvider = Provider<DeleteContactUseCase>(
  (ref) => DeleteContactUseCase(ref.watch(contactsRepositoryProvider)),
);

final searchContactsUseCaseProvider = Provider<SearchContactsUseCase>(
  (ref) => SearchContactsUseCase(ref.watch(contactsRepositoryProvider)),
);

final importContactsUseCaseProvider = Provider<ImportContactsUseCase>(
  (ref) => ImportContactsUseCase(ref.watch(contactsRepositoryProvider)),
);

/// The book as the screens see it.
class ContactsState extends Equatable {
  const ContactsState({
    this.book = ContactBook.empty,
    this.isStored = false,
    this.isSyncing = false,
    this.failure,
  });

  final ContactBook book;

  /// Something was stored or read: the book shown is a real answer, even
  /// when empty, rather than "not known yet".
  final bool isStored;

  final bool isSyncing;

  /// Why the last sync failed; cleared by the next one.
  final Failure? failure;

  /// Nothing to show and something on its way: the skeleton's moment.
  bool get isFirstLoad => !isStored && isSyncing;

  ContactsState copyWith({
    ContactBook? book,
    bool? isStored,
    bool? isSyncing,
    Failure? Function()? failure,
  }) {
    return ContactsState(
      book: book ?? this.book,
      isStored: isStored ?? this.isStored,
      isSyncing: isSyncing ?? this.isSyncing,
      failure: failure == null ? this.failure : failure(),
    );
  }

  @override
  List<Object?> get props => [book, isStored, isSyncing, failure];
}

/// The address book, drawn from this device's copy and kept in step with
/// the server.
///
/// [build] reads only the local store — never the network, never auth — so
/// anything that merely wants a local name (the chat list, a chat header)
/// can watch this without a request being made on its behalf. Requests are
/// made by [sync] and the edits, which the contacts tab and
/// [contactsLifecycleProvider] call.
class ContactsController extends Notifier<ContactsState> {
  @override
  ContactsState build() {
    final stored = ref.watch(contactsLocalStoreProvider).read();
    return ContactsState(
      book: ContactBook(stored?.contacts ?? const <Contact>[]),
      isStored: stored != null,
    );
  }

  int? get _ownerId => ref.read(authProvider).value?.id;

  /// A delta from the last `version`, or the whole list when the policy says
  /// it is time — or when [forceFull], which pull-to-refresh asks for.
  Future<void> sync({bool forceFull = false}) async {
    final ownerId = _ownerId;
    if (ownerId == null) return;

    state = state.copyWith(isSyncing: true, failure: () => null);
    final result = await ref
        .read(syncContactsUseCaseProvider)
        .execute(ownerId: ownerId, forceFull: forceFull);
    if (!ref.mounted) return;

    // Signed out — or in as somebody else — while the pages were read: the
    // book that came back is not this session's to show or to keep.
    if (_ownerId != ownerId) {
      if (_ownerId == null) await forget();
      return;
    }

    state = result.match(
      (failure) => state.copyWith(isSyncing: false, failure: () => failure),
      (snapshot) =>
          ContactsState(book: ContactBook(snapshot.contacts), isStored: true),
    );
  }

  Future<Either<Failure, Contact>> add({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    final result = await ref
        .read(saveContactUseCaseProvider)
        .execute(
          userId: userId,
          username: username,
          firstName: firstName,
          lastName: lastName,
        );
    _reload();
    return result;
  }

  Future<Either<Failure, Contact>> rename(
    int userId, {
    String? firstName,
    String? lastName,
  }) async {
    final result = await ref
        .read(editContactUseCaseProvider)
        .rename(userId, firstName: firstName, lastName: lastName);
    _reload();
    return result;
  }

  /// Flips the star at once and puts it back if the server says no.
  Future<Either<Failure, Contact>> setFavorite(
    int userId,
    bool isFavorite,
  ) async {
    final before = state.book[userId];
    if (before != null) {
      _show(before.copyWith(isFavorite: isFavorite));
    }

    final result = await ref
        .read(editContactUseCaseProvider)
        .setFavorite(userId, isFavorite);
    _reload();
    return result;
  }

  /// Takes the row away at once and brings it back if the server says no —
  /// unless it says the contact was gone already.
  Future<Either<Failure, void>> remove(int userId) async {
    final before = state.book;
    state = state.copyWith(
      book: ContactBook([
        for (final contact in before.contacts)
          if (contact.userId != userId) contact,
      ]),
    );

    final result = await ref.read(deleteContactUseCaseProvider).execute(userId);
    if (!ref.mounted) return result;

    result.match((failure) {
      if (failure is! ContactNotFoundFailure) {
        state = state.copyWith(book: before);
      }
    }, (_) {});
    return result;
  }

  Future<Either<Failure, ContactImportResult>> import(
    List<ContactImportEntry> entries, {
    required String Function(List<ContactImportEntry> batch) keyFor,
  }) async {
    final result = await ref
        .read(importContactsUseCaseProvider)
        .execute(entries, keyFor: keyFor);
    _reload();
    return result;
  }

  /// Drops the book — the account it belonged to signed out.
  Future<void> forget() async {
    await ref.read(contactsLocalStoreProvider).clear();
    if (!ref.mounted) return;
    state = const ContactsState();
  }

  void _show(Contact contact) {
    state = state.copyWith(
      book: ContactBook([
        for (final row in state.book.contacts)
          if (row.userId != contact.userId) row,
        contact,
      ]),
    );
  }

  /// The repository writes every answer through to the store; this brings
  /// the screen level with it.
  void _reload() {
    if (!ref.mounted) return;
    final stored = ref.read(contactsLocalStoreProvider).read();
    if (stored == null) return;
    state = state.copyWith(book: ContactBook(stored.contacts), isStored: true);
  }
}

final contactsProvider = NotifierProvider<ContactsController, ContactsState>(
  ContactsController.new,
);

/// One person's book entry, or null — what a profile asks before offering
/// "add" or "edit".
final contactOfProvider = Provider.family<Contact?, int>(
  (ref, userId) => ref.watch(contactsProvider.select((s) => s.book[userId])),
);

/// The name the owner gave [userId], or null.
///
/// What the chat list and a direct chat's header put in place of the
/// person's display name, as Telegram does. Watching it rebuilds only when
/// that one name changes.
final contactLocalNameProvider = Provider.family<String?, int>(
  (ref, userId) =>
      ref.watch(contactsProvider.select((s) => s.book.localNameOf(userId))),
);

/// The book cut up for the list: favourites, then every contact under its
/// letter. Worked out once per book and language rather than on every
/// rebuild of the screen.
class ContactListLayout extends Equatable {
  const ContactListLayout({
    this.favorites = const <Contact>[],
    this.sections = const <ContactSection>[],
  });

  final List<Contact> favorites;
  final List<ContactSection> sections;

  @override
  List<Object?> get props => [favorites, sections];
}

final contactListLayoutProvider = Provider.family<ContactListLayout, String>((
  ref,
  languageCode,
) {
  final book = ref.watch(contactsProvider.select((state) => state.book));
  return ContactListLayout(
    favorites: book.favorites(languageCode: languageCode),
    sections: book.sections(languageCode: languageCode),
  );
});
