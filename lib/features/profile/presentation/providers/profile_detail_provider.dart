import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

final profileDetailProvider = FutureProvider.family<ProfileEntity, int>((
  ref,
  profileId,
) async {
  final result = await ref.watch(getProfileUseCaseProvider).execute(profileId);

  return result.fold((failure) => throw failure, (profile) => profile);
});
