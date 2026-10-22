import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_photo.dart';
import 'package:chatix/features/profile/domain/usecases/get_profile_by_username_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// [profileId]'s photo history, current first (api-docs §4.5.1).
///
/// Empty — not an error — when the person's `photo` privacy setting or a
/// block keeps this viewer out: the server answers `200` with no items,
/// the same way it sends `avatars: {}` on the profile.
final profilePhotosProvider = FutureProvider.autoDispose
    .family<List<ProfilePhoto>, int>((ref, profileId) async {
      final result = await ref
          .watch(getProfilePhotosUseCaseProvider)
          .execute(profileId);
      return result.fold((failure) => throw failure, (photos) => photos);
    });

/// Somebody by their `@handle`, for a profile link (`/u/{username}`).
///
/// Keyed by the handle as written; the lookup itself ignores case.
final profileByUsernameProvider = FutureProvider.autoDispose
    .family<ProfileEntity, String>((ref, username) async {
      final result = await ref
          .watch(getProfileByUsernameUseCaseProvider)
          .execute(username);
      return result.fold((failure) => throw failure, (profile) => profile);
    });

/// Whether [error] means "there is nobody by that name" rather than "it
/// could not be asked": `404 NOT_FOUND_PROFILE`, or a handle that was
/// empty to begin with.
bool isUnknownUsername(Object? error) => switch (error) {
  ApiFailure(:final code) => code == 'NOT_FOUND_PROFILE',
  InputFailure() => true,
  _ => false,
};

/// The two things one does to one's own old photos, each followed by a
/// fresh read of the history and of the profile, whose `avatars` it may
/// have changed. The chats catch up on their own: the server sends
/// `profiles.profile.updated` after any change of the current photo.
class ProfilePhotoActions {
  const ProfilePhotoActions(this._ref);

  final Ref _ref;

  Future<Failure?> makeMain(int profileId, String photoId) => _run(
    profileId,
    _ref.read(manageProfilePhotosUseCaseProvider).makeMain(photoId),
  );

  Future<Failure?> delete(int profileId, String photoId) => _run(
    profileId,
    _ref.read(manageProfilePhotosUseCaseProvider).delete(photoId),
  );

  Future<Failure?> _run(
    int profileId,
    Future<Either<Failure, void>> request,
  ) async {
    final failure = (await request).getLeft().toNullable();
    if (failure == null) {
      _ref
        ..invalidate(profilePhotosProvider(profileId))
        ..invalidate(profileDetailProvider(profileId));
    }
    return failure;
  }
}

final profilePhotoActionsProvider = Provider<ProfilePhotoActions>(
  ProfilePhotoActions.new,
);

/// The handle a `/u/{username}` link carries, normalised the way the lookup
/// will normalise it — so `@Durov` and `durov ` share one entry.
String usernameKey(String raw) =>
    GetProfileByUsernameUseCase.normalize(raw) ?? '';
