import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Domain-layer DI. `authRepositoryProvider` itself lives next to its
/// implementation in `auth_repository_impl.dart` (re-exported here isn't
/// needed — import that file directly where the repository is required).
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

final requestEmailVerificationUseCaseProvider = Provider<RequestEmailVerificationUseCase>((ref) {
  return RequestEmailVerificationUseCase(ref.watch(authRepositoryProvider));
});

final confirmEmailVerificationUseCaseProvider = Provider<ConfirmEmailVerificationUseCase>((ref) {
  return ConfirmEmailVerificationUseCase(ref.watch(authRepositoryProvider));
});

final requestPasswordResetUseCaseProvider = Provider<RequestPasswordResetUseCase>((ref) {
  return RequestPasswordResetUseCase(ref.watch(authRepositoryProvider));
});

final confirmPasswordResetUseCaseProvider = Provider<ConfirmPasswordResetUseCase>((ref) {
  return ConfirmPasswordResetUseCase(ref.watch(authRepositoryProvider));
});

final getOAuthUrlUseCaseProvider = Provider<GetOAuthUrlUseCase>((ref) {
  return GetOAuthUrlUseCase(ref.watch(authRepositoryProvider));
});
