import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/domain/entities/profile_update.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

class ProfileEditController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Saves [update] as the profile's whole editable state.
  ///
  /// Whole, not partial: `PUT /profiles/{id}/` writes the body onto the row
  /// as it stands, so a field missing from the request is erased rather than
  /// left alone (api-docs §4.4). The form builds a complete [ProfileUpdate]
  /// for exactly that reason.
  Future<bool> submit(int profileId, ProfileUpdate update) async {
    state = const AsyncValue.loading();

    final result = await ref
        .read(updateProfileUseCaseProvider)
        .execute(profileId, update);

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

  Future<bool> addContact(
    int profileId, {
    required String provider,
    required String contact,
  }) async {
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

    final result = await ref
        .read(removeContactUseCaseProvider)
        .execute(profileId, provider: provider);

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
