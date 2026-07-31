import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// Backs `ProfileEditScreen`. There's no family/`profileId` argument on
/// purpose — per api-docs §4.4/§4.6, editing is only ever allowed for the
/// caller's own profile (no system-rights UI exists yet, see
/// `ProfileScreen.canEdit`), so every method here just takes the id to act
/// on as a plain parameter instead of needing a separate provider instance
/// per profile.
class ProfileEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// `PUT /profiles/{profileId}/`. ⚠️ Per `UpdateProfileUseCase`, pass the
  /// full current value of every field the person didn't intend to blank
  /// out — this is not a partial update on the wire.
  Future<bool> submit(
    int profileId, {
    String? specialization,
    String? displayName,
    String? bio,
    List<String>? skills,
    DateTime? dateBirthday,
  }) async {
    state = const AsyncValue.loading();

    final result = await ref.read(updateProfileUseCaseProvider).execute(
      profileId,
      specialization: specialization,
      displayName: displayName,
      bio: bio,
      skills: skills,
      dateBirthday: dateBirthday,
    );

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(profileDetailProvider(profileId));
        return true;
      },
    );
  }

  Future<bool> addContact(int profileId, {required String provider, required String contact}) async {
    state = const AsyncValue.loading();

    final result = await ref
        .read(addContactUseCaseProvider)
        .execute(profileId, provider: provider, contact: contact);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(profileDetailProvider(profileId));
        return true;
      },
    );
  }

  Future<bool> removeContact(int profileId, {required String provider}) async {
    state = const AsyncValue.loading();

    final result = await ref.read(removeContactUseCaseProvider).execute(profileId, provider: provider);

    return result.fold(
      (failure) {
        state = AsyncValue.error(failure, StackTrace.current);
        return false;
      },
      (_) {
        state = const AsyncValue.data(null);
        ref.invalidate(profileDetailProvider(profileId));
        return true;
      },
    );
  }
}

final profileEditProvider = AsyncNotifierProvider<ProfileEditController, void>(
  ProfileEditController.new,
);
