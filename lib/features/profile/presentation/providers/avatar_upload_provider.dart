import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';

/// How long to wait for the background task that turns an uploaded file
/// into an avatar.
///
/// A provider rather than a constant so a test does not have to spend ten
/// real seconds proving that a rejected picture is reported (api-docs §4.5).
class AvatarPollSchedule {
  const AvatarPollSchedule({
    this.attempts = 8,
    this.interval = const Duration(milliseconds: 1250),
  });

  final int attempts;
  final Duration interval;
}

final avatarPollScheduleProvider = Provider<AvatarPollSchedule>(
  (ref) => const AvatarPollSchedule(),
);

/// The picture a run of the upload is carrying, kept so the same one can be
/// sent again without asking the user to find it twice.
class AvatarAttempt extends Equatable {
  const AvatarAttempt({
    required this.profileId,
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final int profileId;
  final Uint8List bytes;
  final String filename;
  final String contentType;

  @override
  List<Object?> get props => [profileId, filename, contentType, bytes.length];
}

/// Uploading one avatar, from picking it to knowing whether it stuck.
///
/// The last step is the unusual one. `POST /profiles/avatar/upload_complete/`
/// answers `200` and queues a background task; that task is what checks the
/// real MIME type and the 5 MB cap, and when it rejects the file nothing is
/// sent back — the avatar simply never changes (api-docs §4.5, §2.5). So
/// "done" cannot be claimed when the request returns: the profile is polled
/// until its `avatars` map changes, and a map that never changes is reported
/// as a failed upload the user can retry.
class AvatarUploadController extends AsyncNotifier<AvatarUploadStage?> {
  AvatarAttempt? _lastAttempt;

  /// The picture the last run tried to send, when that run failed. Null
  /// while idle, mid-flight, or after a success.
  AvatarAttempt? get lastAttempt => _lastAttempt;

  @override
  Future<AvatarUploadStage?> build() async => null;

  Future<void> upload({
    required int profileId,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) {
    return _run(
      AvatarAttempt(
        profileId: profileId,
        bytes: bytes,
        filename: filename,
        contentType: contentType,
      ),
    );
  }

  /// Sends the picture from the run that just failed, again.
  Future<void> retry() async {
    final attempt = _lastAttempt;
    if (attempt == null) return;
    await _run(attempt);
  }

  Future<void> _run(AvatarAttempt attempt) async {
    state = const AsyncValue.loading();
    _lastAttempt = attempt;

    final before = await _readAvatars();

    final stream = ref
        .read(uploadAvatarUseCaseProvider)
        .execute(
          bytes: attempt.bytes,
          filename: attempt.filename,
          contentType: attempt.contentType,
        );

    await for (final event in stream) {
      final failure = event.getLeft().toNullable();
      if (failure != null) {
        state = AsyncValue.error(failure, StackTrace.current);
        return;
      }
      state = AsyncValue.data(event.getRight().toNullable());
    }

    // `done` from the use case only means the confirm request was accepted.
    // Whether the picture is any good is decided later, by a task nobody can
    // ask about, so the real answer comes from the poll below.
    if (state.value != AvatarUploadStage.done) return;

    state = const AsyncValue.data(AvatarUploadStage.processing);
    await _awaitProcessing(attempt.profileId, before: before);
  }

  /// Polls until the avatar map changes, or gives up and says so.
  Future<void> _awaitProcessing(
    int profileId, {
    required Map<String, Map<String, String>>? before,
  }) async {
    final schedule = ref.read(avatarPollScheduleProvider);

    for (var attempt = 0; attempt < schedule.attempts; attempt++) {
      await Future<void>.delayed(schedule.interval);
      if (!ref.mounted) return;

      final avatars = await _readAvatars();
      if (!ref.mounted) return;

      if (avatars == null) continue;
      if (before != null && _sameAvatars(avatars, before)) continue;
      if (avatars.isEmpty) continue;

      _lastAttempt = null;
      state = const AsyncValue.data(AvatarUploadStage.done);
      ref.invalidate(profileDetailProvider(profileId));
      return;
    }

    if (!ref.mounted) return;

    Logger.warning('AvatarUpload: the new avatar never appeared');

    // Deliberately not a message of its own: the UI names this state, and
    // `AvatarProcessingFailure` is what tells it apart from a transport
    // error that has a message worth showing.
    state = AsyncValue.error(
      const AvatarProcessingFailure(),
      StackTrace.current,
    );
  }

  /// The avatar map as the server currently has it, or null when it could
  /// not be read — a failed poll is not a failed upload, so it is skipped
  /// rather than treated as "unchanged".
  /// Reads through `GET /profiles/my/`, which needs no id: an avatar can
  /// only ever be set on one's own profile (api-docs §4.5).
  Future<Map<String, Map<String, String>>?> _readAvatars() async {
    final result = await ref.read(ensureMyProfileUseCaseProvider).execute();

    return result.match<Map<String, Map<String, String>>?>((failure) {
      Logger.warning('AvatarUpload: profile poll failed (${failure.message})');
      return null;
    }, (ProfileEntity profile) => profile.avatars);
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
    _lastAttempt = null;
    state = const AsyncValue.data(null);
  }
}

final avatarUploadProvider =
    AsyncNotifierProvider<AvatarUploadController, AvatarUploadStage?>(
      AvatarUploadController.new,
    );
