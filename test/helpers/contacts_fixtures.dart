import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_remote_data_source.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

const int kOwnerId = 7;

final DateTime kCreated = DateTime.utc(2026, 9, 1, 12);

/// A contact as the server would send it, with only what a test cares
/// about spelled out.
Contact contact(
  int userId, {
  String? displayName,
  String? username,
  String? firstName,
  String? lastName,
  bool isFavorite = false,
  bool isMutual = false,
  DateTime? updatedAt,
  bool withProfile = true,
  int ownerId = kOwnerId,
}) {
  return Contact(
    ownerId: ownerId,
    userId: userId,
    firstName: firstName,
    lastName: lastName,
    source: ContactSource.username,
    isMutual: isMutual,
    isFavorite: isFavorite,
    createdAt: kCreated,
    updatedAt: updatedAt ?? kCreated,
    profile: withProfile
        ? ContactProfile(
            id: userId,
            username: username ?? 'user$userId',
            displayName: displayName,
          )
        : null,
  );
}

/// One recorded `GET /contacts/`.
class PageRequest {
  const PageRequest({this.afterContactId, this.updatedAfter, this.limit});

  final int? afterContactId;
  final String? updatedAfter;
  final int? limit;

  @override
  String toString() =>
      'PageRequest(after: $afterContactId, updatedAfter: $updatedAfter)';
}

/// `/contacts` with scripted answers and a record of what was asked.
class FakeContactsRemote implements ContactsRemoteDataSource {
  FakeContactsRemote({this.onPage});

  /// Answers one page request; defaults to an empty last page.
  Future<Either<Failure, ContactPage>> Function(PageRequest request)? onPage;

  Future<Either<Failure, Contact>> Function({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  })?
  onAdd;

  Future<Either<Failure, Contact>> Function(
    int userId,
    Map<String, dynamic> body,
  )?
  onUpdate;

  Future<Either<Failure, void>> Function(int userId)? onDelete;

  Future<Either<Failure, List<ContactSearchHit>>> Function(String query)?
  onSearch;

  Future<Either<Failure, ContactImportResult>> Function(
    List<ContactImportEntry> entries,
    String idempotencyKey,
  )?
  onImport;

  final List<PageRequest> pages = <PageRequest>[];
  final List<String> searches = <String>[];
  final List<(int, Map<String, dynamic>)> updates = [];
  final List<int> deletes = <int>[];
  final List<(List<ContactImportEntry>, String)> imports = [];

  @override
  Future<Either<Failure, ContactPage>> fetchPage({
    int limit = ContactsApi.pageSize,
    int? afterContactId,
    String? updatedAfter,
  }) {
    final request = PageRequest(
      afterContactId: afterContactId,
      updatedAfter: updatedAfter,
      limit: limit,
    );
    pages.add(request);
    final answer = onPage;
    if (answer == null) {
      return Future.value(
        const Right(ContactPage(contacts: [], hasNext: false, version: 'v0')),
      );
    }
    return answer(request);
  }

  @override
  Future<Either<Failure, Contact>> add({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  }) {
    return onAdd!(
      userId: userId,
      username: username,
      firstName: firstName,
      lastName: lastName,
    );
  }

  @override
  Future<Either<Failure, Contact>> update(
    int userId,
    Map<String, dynamic> body,
  ) {
    updates.add((userId, body));
    return onUpdate!(userId, body);
  }

  @override
  Future<Either<Failure, void>> delete(int userId) {
    deletes.add(userId);
    return onDelete?.call(userId) ?? Future.value(const Right(null));
  }

  @override
  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    int limit = ContactsApi.searchLimit,
    RequestCancellation? cancellation,
  }) {
    searches.add(query);
    return onSearch?.call(query) ??
        Future.value(const Right(<ContactSearchHit>[]));
  }

  @override
  Future<Either<Failure, ContactImportResult>> importContacts(
    List<ContactImportEntry> entries, {
    required String idempotencyKey,
  }) {
    imports.add((entries, idempotencyKey));
    return onImport!(entries, idempotencyKey);
  }
}

/// A book of [contacts] split into pages of [size], each pointing at the
/// next by the last id on it — the way the server pages (api-docs §4.8).
Future<Either<Failure, ContactPage>> Function(PageRequest) pagesOf(
  List<Contact> contacts, {
  required int size,
  String version = 'v1',
}) {
  final sorted = [...contacts]..sort((a, b) => a.userId.compareTo(b.userId));
  return (request) async {
    final after = request.afterContactId;
    final rest = after == null
        ? sorted
        : sorted.where((c) => c.userId > after).toList();
    final page = rest.take(size).toList();
    final hasNext = rest.length > size;
    return Right(
      ContactPage(
        contacts: page,
        hasNext: hasNext,
        nextContactId: hasNext ? page.last.userId : null,
        version: hasNext ? null : version,
      ),
    );
  };
}
