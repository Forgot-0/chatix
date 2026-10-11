import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/api_client.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/features/contacts/data/models/contact_models.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';

/// The block list as the server has it (api-docs §4.13).
///
/// `/contacts/blocked/` is declared before `/contacts/{user_id}/` on the
/// server, and without its trailing slash it is a 404, not a list (§0.18).
abstract interface class BlockedUsersRemoteDataSource {
  /// One page of `GET /contacts/blocked/`, ordered by `target_id`.
  Future<Either<Failure, BlockedPage>> fetchPage({
    int limit = BlockedUsersApi.screenPageSize,
    int? afterTargetId,
  });

  /// `POST /contacts/{user_id}/block/` → `204`.
  Future<Either<Failure, void>> block(int userId);

  /// `DELETE /contacts/{user_id}/block/` → `204`.
  Future<Either<Failure, void>> unblock(int userId);
}

abstract final class BlockedUsersApi {
  static const String blocked = '/contacts/blocked/';

  static String block(int userId) => '/contacts/$userId/block/';

  /// What the screen asks for at a time: a screenful and a half, so the
  /// cursor is used rather than one request carrying everybody.
  static const int screenPageSize = 50;

  /// The most one page may hold (1..500): what a full sync asks for, so a
  /// list of any ordinary length is one request.
  static const int maxPageSize = 500;
}

class BlockedUsersRemoteDataSourceImpl implements BlockedUsersRemoteDataSource {
  BlockedUsersRemoteDataSourceImpl(this._api);

  final ApiClient _api;

  @override
  Future<Either<Failure, BlockedPage>> fetchPage({
    int limit = BlockedUsersApi.screenPageSize,
    int? afterTargetId,
  }) async {
    final result = await _api.get(
      BlockedUsersApi.blocked,
      queryParameters: {'limit': limit, 'after_target_id': ?afterTargetId},
    );
    return result.map(
      (data) => ContactJson.blockedPage(
        data is Map ? data.cast<String, dynamic>() : const <String, dynamic>{},
      ),
    );
  }

  @override
  Future<Either<Failure, void>> block(int userId) async {
    final result = await _api.post(BlockedUsersApi.block(userId));
    return result.map((_) {});
  }

  @override
  Future<Either<Failure, void>> unblock(int userId) async {
    final result = await _api.delete(BlockedUsersApi.block(userId));
    return result.map((_) {});
  }
}

final blockedUsersRemoteDataSourceProvider =
    Provider<BlockedUsersRemoteDataSource>(
      (ref) => BlockedUsersRemoteDataSourceImpl(ref.watch(apiClientProvider)),
    );
