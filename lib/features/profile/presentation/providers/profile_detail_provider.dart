import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// One profile, by id.
///
/// Two different reads behind one provider, because the API has two:
///
/// * the signed-in user's own profile goes through `GET /profiles/my/`, which
///   creates the row if the `auth.user.verified` consumer has not got to it
///   yet and therefore always answers `200` (api-docs §4.1);
/// * anyone else's goes through `GET /profiles/{id}/`, which can answer `404`
///   during that same window — `GetProfileUseCase` retries it rather than
///   reporting a real person as missing (api-docs §0.8).
final profileDetailProvider = FutureProvider.family<ProfileEntity, int>((
  ref,
  profileId,
) async {
  final myUserId = ref.watch(authProvider.select((user) => user.value?.id));

  final result = profileId == myUserId
      ? await ref.watch(ensureMyProfileUseCaseProvider).execute()
      : await ref.watch(getProfileUseCaseProvider).execute(profileId);

  return result.fold((failure) => throw failure, (profile) => profile);
});
