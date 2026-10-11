import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/network/request_cancellation.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/contacts/data/models/contact_models.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

/// `/contacts` as the server has it (api-docs §4.7–4.13).
///
/// Every path ends in a slash: the server does not redirect, and
/// `/contacts/search` without one is a 404 rather than a search (§0.1,
/// §0.18).
abstract interface class ContactsRemoteDataSource {
  /// One page of `GET /contacts/`, ordered by `contact_id`.
  Future<Either<Failure, ContactPage>> fetchPage({
    int limit = ContactsApi.pageSize,
    int? afterContactId,
    String? updatedAfter,
  });

  Future<Either<Failure, Contact>> add({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  });

  /// `PATCH /contacts/{user_id}/` with exactly the keys in [body].
  Future<Either<Failure, Contact>> update(
    int userId,
    Map<String, dynamic> body,
  );

  Future<Either<Failure, void>> delete(int userId);

  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    int limit = ContactsApi.searchLimit,
    RequestCancellation? cancellation,
  });

  Future<Either<Failure, ContactImportResult>> importContacts(
    List<ContactImportEntry> entries, {
    required String idempotencyKey,
  });
}

abstract final class ContactsApi {
  static const String contacts = '/contacts/';
  static const String search = '/contacts/search/';
  static const String import = '/contacts/import/';

  static String contact(int userId) => '/contacts/$userId/';

  /// The largest page the server serves (1..500, api-docs §4.8): a book of
  /// the maximum 5000 contacts reads in ten requests.
  static const int pageSize = 500;

  /// The most `GET /contacts/search/` returns (1..50).
  static const int searchLimit = 50;

  static const String idempotencyHeader = 'Idempotency-Key';
}

class ContactsRemoteDataSourceImpl implements ContactsRemoteDataSource {
  ContactsRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<Either<Failure, ContactPage>> fetchPage({
    int limit = ContactsApi.pageSize,
    int? afterContactId,
    String? updatedAfter,
  }) async {
    final result = await _api.get(
      ContactsApi.contacts,
      queryParameters: {
        'limit': limit,
        'after_contact_id': ?afterContactId,
        'updated_after': ?updatedAfter,
      },
    );
    return result.map((data) => ContactJson.page(_map(data)));
  }

  @override
  Future<Either<Failure, Contact>> add({
    int? userId,
    String? username,
    String? firstName,
    String? lastName,
  }) async {
    final result = await _api.post(
      ContactsApi.contacts,
      data: {
        'user_id': ?userId,
        'username': ?username,
        'first_name': ?firstName,
        'last_name': ?lastName,
      },
    );
    return result.map((data) => ContactJson.contact(_map(data)));
  }

  @override
  Future<Either<Failure, Contact>> update(
    int userId,
    Map<String, dynamic> body,
  ) async {
    final result = await _api.patch(ContactsApi.contact(userId), data: body);
    return result.map((data) => ContactJson.contact(_map(data)));
  }

  @override
  Future<Either<Failure, void>> delete(int userId) async {
    final result = await _api.delete(ContactsApi.contact(userId));
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, List<ContactSearchHit>>> search(
    String query, {
    int limit = ContactsApi.searchLimit,
    RequestCancellation? cancellation,
  }) async {
    final result = await _api.get(
      ContactsApi.search,
      queryParameters: {'query': query, 'limit': limit},
      cancelToken: cancellation?.dioToken,
    );
    return result.map((data) => ContactJson.searchHits(_map(data)));
  }

  @override
  Future<Either<Failure, ContactImportResult>> importContacts(
    List<ContactImportEntry> entries, {
    required String idempotencyKey,
  }) async {
    // `200 done` up to 100 entries, `202 queued` above (api-docs §4.11); the
    // body says which, so the status code itself is not needed.
    final result = await _api.post(
      ContactsApi.import,
      data: ContactJson.importRequest(entries),
      options: Options(
        headers: {ContactsApi.idempotencyHeader: idempotencyKey},
      ),
    );
    return result.map((data) => ContactJson.importResult(_map(data)));
  }

  static Map<String, dynamic> _map(Object? data) =>
      data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{};
}

final contactsRemoteDataSourceProvider = Provider<ContactsRemoteDataSource>(
  (ref) => ContactsRemoteDataSourceImpl(ref.watch(apiClientProvider)),
);
