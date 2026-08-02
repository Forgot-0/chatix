import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// `GET /profiles/{id}/` for a single profile, keyed by [profileId]. When the
/// requested profile belongs to the signed-in user, the provider swaps to
/// `GET /profiles/my/` so the backend can resolve the caller's own profile
/// from the JWT instead of requiring a numeric id.
final profileDetailProvider = FutureProvider.family<ProfileEntity, int>((
  ref,
  profileId,
) async {
  final currentUserId = ref.watch(authProvider).value?.id;

  final result = profileId == currentUserId
      ? await ref.watch(getMyProfileUseCaseProvider).execute()
      : await ref.watch(getProfileUseCaseProvider).execute(profileId);

  return result.fold((failure) => throw failure, (profile) => profile);
});
