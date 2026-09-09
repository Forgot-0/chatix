import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/usecases/get_my_sessions_use_case.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/usecases/confirm_email_verification_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/confirm_password_reset_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/get_current_user_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/get_oauth_url_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/login_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/logout_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/register_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/request_email_verification_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/request_password_reset_use_case.dart';

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final getCurrentUserUseCaseProvider = Provider<GetCurrentUserUseCase>((ref) {
  return GetCurrentUserUseCase(ref.watch(authRepositoryProvider));
});

final requestEmailVerificationUseCaseProvider =
    Provider<RequestEmailVerificationUseCase>((ref) {
      return RequestEmailVerificationUseCase(ref.watch(authRepositoryProvider));
    });

final confirmEmailVerificationUseCaseProvider =
    Provider<ConfirmEmailVerificationUseCase>((ref) {
      return ConfirmEmailVerificationUseCase(ref.watch(authRepositoryProvider));
    });

final requestPasswordResetUseCaseProvider =
    Provider<RequestPasswordResetUseCase>((ref) {
      return RequestPasswordResetUseCase(ref.watch(authRepositoryProvider));
    });

final confirmPasswordResetUseCaseProvider =
    Provider<ConfirmPasswordResetUseCase>((ref) {
      return ConfirmPasswordResetUseCase(ref.watch(authRepositoryProvider));
    });

final getOAuthUrlUseCaseProvider = Provider<GetOAuthUrlUseCase>((ref) {
  return GetOAuthUrlUseCase(ref.watch(authRepositoryProvider));
});

final getMySessionsUseCaseProvider = Provider<GetMySessionsUseCase>((ref) {
  return GetMySessionsUseCase(ref.watch(authRepositoryProvider));
});

/// The caller's own signed-in devices. Auto-refreshes on invalidate; there is
/// no realtime channel for sessions.
final mySessionsProvider = FutureProvider<List<SessionEntity>>((ref) async {
  final result = await ref.watch(getMySessionsUseCaseProvider).execute();
  return result.fold((failure) => throw failure, (sessions) => sessions);
});
