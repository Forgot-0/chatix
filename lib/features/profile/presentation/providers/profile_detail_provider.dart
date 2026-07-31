import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// `GET /profiles/{id}/` (api-docs §4.3) for a single profile, keyed by
/// [profileId]. A plain `FutureProvider.family` is enough here — there's no
/// local mutation to model, just "fetch this id". `ProfileEditController`
/// invalidates the relevant entry after a successful write so the view
/// screen picks up fresh data without a manual pull-to-refresh.
final profileDetailProvider = FutureProvider.family<ProfileEntity, int>((ref, profileId) async {
  final result = await ref.watch(getProfileUseCaseProvider).execute(profileId);
  return result.fold((failure) => throw failure, (profile) => profile);
});
