import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

class AvatarUploadController extends AsyncNotifier<AvatarUploadStage?> {
  @override
  Future<AvatarUploadStage?> build() async => null;

  Future<void> upload({
    required int profileId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    state = const AsyncValue.loading();

    final before =
        ref.read(profileDetailProvider(profileId)).value?.avatars ??
        const <String, Map<String, String>>{};

    final stream = ref
        .read(uploadAvatarUseCaseProvider)
        .execute(bytes: bytes, filename: filename, contentType: contentType);

    await for (final event in stream) {
      state = event.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (stage) => AsyncValue.data(stage),
      );
    }

    if (state.value != AvatarUploadStage.done) return;

    await _awaitProcessing(profileId, before: before);
  }

  static const _pollAttempts = 6;
  static const _pollInterval = Duration(seconds: 2);

  Future<void> _awaitProcessing(
    int profileId, {
    required Map<String, Map<String, String>> before,
  }) async {
    for (var attempt = 0; attempt < _pollAttempts; attempt++) {
      await Future<void>.delayed(_pollInterval);
      if (!ref.mounted) return;

      ref.invalidate(profileDetailProvider(profileId));

      final ProfileEntity profile;
      try {
        profile = await ref.read(profileDetailProvider(profileId).future);
      } catch (error) {
        Logger.warning('AvatarUpload: profile poll failed ($error)');
        continue;
      }

      if (!_sameAvatars(profile.avatars, before)) return;
    }

    if (!ref.mounted) return;

    state = AsyncValue.error(
      const ServerFailure(
        message:
            "That image couldn't be processed. Please try a different one.",
      ),
      StackTrace.current,
    );
  }

  bool _sameAvatars(
    Map<String, Map<String, String>> a,
    Map<String, Map<String, String>> b,
  ) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      final other = b[entry.key];
      if (other == null || other.length != entry.value.length) return false;
      for (final format in entry.value.entries) {
        if (other[format.key] != format.value) return false;
      }
    }
    return true;
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final avatarUploadProvider =
    AsyncNotifierProvider<AvatarUploadController, AvatarUploadStage?>(
      AvatarUploadController.new,
    );
