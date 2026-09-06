import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// Bridges `UploadAvatarUseCase`'s
/// `Stream<Either<Failure, AvatarUploadStage>>` into a plain
/// `AsyncValue<AvatarUploadStage?>` so
/// `AvatarPickerWidget` can drive a step indicator the same way it would
/// for any other async operation: `loading` while idle-but-not-started
/// isn't distinguished from "nothing happening yet" (`data(null)`) — the
/// widget only starts caring once [upload] is called.
///
/// ⚠️ [AvatarUploadStage.done] from the use case means "the backend queued the
/// resize job", not "the avatar changed" (api-docs §0.10, §4.5). This
/// controller therefore does not surface `done` until it has confirmed the new
/// `avatars` actually appeared — see [_awaitProcessing].
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

    // Captured before anything is sent: the completion check below is "did
    // `avatars` change", and after the upload there is nothing left to
    // compare against.
    final before =
        ref.read(profileDetailProvider(profileId)).value?.avatars ??
        const <String, Map<String, String>>{};

    final stream = ref.read(uploadAvatarUseCaseProvider).execute(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );

    await for (final event in stream) {
      state = event.fold(
        (failure) => AsyncValue.error(failure, StackTrace.current),
        (stage) => AsyncValue.data(stage),
      );
    }

    if (state.value != AvatarUploadStage.done) return;

    await _awaitProcessing(profileId, before: before);
  }

  /// How long to keep asking whether the background job has finished, and how
  /// often.
  ///
  /// api-docs §4.5/§10.4 spell out the contract: the resize job runs *after*
  /// `upload_complete` returns, reports its outcome **nowhere**, and the only
  /// way to learn anything is to re-read `GET /profiles/{id}/` and see whether
  /// `avatars` changed. So this is not a nicety — without it a rejected image
  /// (wrong real MIME, over 5 MB) and a successful one are indistinguishable,
  /// and the user is left staring at an unchanged picture.
  static const _pollAttempts = 6;
  static const _pollInterval = Duration(seconds: 2);

  /// Polls the profile until [before] stops being the current avatar set.
  ///
  /// A single immediate re-fetch — what this used to do — almost always loses
  /// the race with the job and shows the *old* avatar, which reads as "nothing
  /// happened" whether the upload worked or not.
  ///
  /// Comparing against the pre-upload snapshot rather than "is `avatars`
  /// non-empty" is what makes this work for a *replacement* avatar, which is
  /// the common case: the map was already non-empty before.
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
        // A failed poll says nothing about the upload — keep trying.
        Logger.warning('AvatarUpload: profile poll failed ($error)');
        continue;
      }

      if (!_sameAvatars(profile.avatars, before)) return;
    }

    if (!ref.mounted) return;

    // The window closed with the avatar unchanged. Per §4.5 that means the
    // background job rejected the file — most likely because its *real* type
    // is not an image (the check is on content, not the extension we sent) or
    // it exceeded 5 MB after all. The server tells us no more than that, so
    // neither can we.
    state = AsyncValue.error(
      const ServerFailure(
        message:
            "That image couldn't be processed. Please try a different one.",
      ),
      StackTrace.current,
    );
  }

  /// Whether two `avatars` maps describe the same set of variants.
  ///
  /// Compares the generated URLs, not just the size/format keys: a
  /// replacement avatar has the *same* shape (4 sizes × 3 formats) and only
  /// differs by the URLs behind it.
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

final avatarUploadProvider = AsyncNotifierProvider<AvatarUploadController, AvatarUploadStage?>(
  AvatarUploadController.new,
);
