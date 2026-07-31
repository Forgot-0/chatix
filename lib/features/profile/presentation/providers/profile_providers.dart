import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/data/datasources/avatar_uploader_impl.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/usecases/add_contact_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/get_profile_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/remove_contact_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';
import 'package:chatix/features/profile/domain/usecases/upload_avatar_use_case.dart';

/// Domain-layer DI. `profileRepositoryProvider` lives next to its
/// implementation in `profile_repository_impl.dart` (mirrors
/// `auth_providers.dart`'s convention) — import that file directly where
/// the repository itself is required.
final getProfilesUseCaseProvider = Provider<GetProfilesUseCase>((ref) {
  return GetProfilesUseCase(ref.watch(profileRepositoryProvider));
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(profileRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(profileRepositoryProvider));
});

final addContactUseCaseProvider = Provider<AddContactUseCase>((ref) {
  return AddContactUseCase(ref.watch(profileRepositoryProvider));
});

final removeContactUseCaseProvider = Provider<RemoveContactUseCase>((ref) {
  return RemoveContactUseCase(ref.watch(profileRepositoryProvider));
});

final uploadAvatarUseCaseProvider = Provider<UploadAvatarUseCase>((ref) {
  return UploadAvatarUseCase(
    ref.watch(profileRepositoryProvider),
    ref.watch(avatarUploaderProvider),
  );
});
