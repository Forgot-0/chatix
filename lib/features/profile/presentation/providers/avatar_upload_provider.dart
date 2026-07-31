import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// Bridges `UploadAvatarUseCase`'s `Stream<Either<Failure,
/// AvatarUploadStage>>` into a plain `AsyncValue<AvatarUploadStage?>` so
/// `AvatarPickerWidget` can drive a step indicator the same way it would
/// for any other async operation: `loading` while idle-but-not-started
/// isn't distinguished from "nothing happening yet" (`data(null)`) — the
/// widget only starts caring once [upload] is called.
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

    if (state.value == AvatarUploadStage.done) {
      // The resized variants are generated asynchronously server-side
      // (api-docs §4.5), so the freshly-fetched profile may briefly still
      // show the old (or no) avatar — that's expected, not a bug here.
      ref.invalidate(profileDetailProvider(profileId));
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

final avatarUploadProvider = AsyncNotifierProvider<AvatarUploadController, AvatarUploadStage?>(
  AvatarUploadController.new,
);
