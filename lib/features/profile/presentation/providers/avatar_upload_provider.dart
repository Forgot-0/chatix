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

      final profile = await _readProfile(profileId);
      if (profile == null) continue;

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

  /// Reads the profile without awaiting `provider.future`.
  ///
  /// That future never completes when the provider throws a `Failure` —
  /// Riverpod only settles it for thrown `Error`s, and a `Failure` is a plain
  /// Equatable. This loop is wrapped in a retry precisely because the fetch can
  /// fail (a 404 right after registration is expected, api-docs §4.1), so
  /// awaiting the future would hang the whole poll instead of retrying.
  /// The AsyncValue carries the same result and settles either way.
  Future<ProfileEntity?> _readProfile(int profileId) async {
    final provider = profileDetailProvider(profileId);

    // Keep the provider alive while it loads; a bare read would let it dispose
    // between polls and restart from scratch.
    final subscription = ref.listen(provider, (_, _) {});
    try {
      for (var tick = 0; tick < _readTicks; tick++) {
        final value = ref.read(provider);

        if (value.hasValue) return value.value;
        if (value.hasError) {
          Logger.warning('AvatarUpload: profile poll failed (${value.error})');
          return null;
        }
        await Future<void>.delayed(_readTick);
      }
    } finally {
      subscription.close();
    }

    Logger.warning('AvatarUpload: profile poll timed out');
    return null;
  }

  /// Bounded wait for one poll to settle, so a stuck request cannot pin the
  /// loop past its own [_pollInterval] budget.
  static const _readTick = Duration(milliseconds: 100);
  static const _readTicks = 30;

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
