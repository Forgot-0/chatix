import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';

/// Lists the caller's own sessions (`GET /users/sessions/`).
///
/// Read-only on purpose: revoking a session is `DELETE /sessions/{id}/`, which
/// requires the admin permission `user:update` (api-docs §3.15) — a normal user
/// cannot end their other sessions through the API.
class GetMySessionsUseCase {
  const GetMySessionsUseCase(this._repository);

  final AuthRepository _repository;

  Future<Either<Failure, List<SessionEntity>>> execute() async {
    final result = await _repository.getMySessions();

    return result.map((sessions) {
      // Newest activity first, and still-active sessions ahead of dead ones.
      final sorted = [...sessions]
        ..sort((a, b) {
          if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
          final x = a.lastActivity;
          final y = b.lastActivity;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
      return sorted;
    });
  }
}
