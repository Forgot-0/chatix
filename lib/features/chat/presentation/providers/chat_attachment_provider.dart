import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_attachment_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Composer-side attachment state for one chat.
///
/// Holds the picked files, the running upload progress and — once the upload
/// finishes — the `upload_tokens` that go into `sendMessage` (api-docs §6.5
/// step 4).
class ChatAttachmentState extends Equatable {
  /// What the user picked, already validated against the §6.5 limits.
  final List<AttachmentUploadRequestEntity> selected;

  final ChatAttachmentUploadProgress? progress;
  final Failure? failure;

  /// Confirmed tokens, ready to be attached to a message.
  final List<String> uploadTokens;

  const ChatAttachmentState({
    this.selected = const [],
    this.progress,
    this.failure,
    this.uploadTokens = const [],
  });

  bool get isUploading =>
      progress != null && progress!.stage != ChatAttachmentUploadStage.done;

  bool get isReady => uploadTokens.isNotEmpty;

  bool get hasSelection => selected.isNotEmpty;

  ChatAttachmentState copyWith({
    List<AttachmentUploadRequestEntity>? selected,
    ChatAttachmentUploadProgress? progress,
    Failure? failure,
    List<String>? uploadTokens,
    bool clearProgress = false,
    bool clearFailure = false,
  }) {
    return ChatAttachmentState(
      selected: selected ?? this.selected,
      progress: clearProgress ? null : (progress ?? this.progress),
      failure: clearFailure ? null : (failure ?? this.failure),
      uploadTokens: uploadTokens ?? this.uploadTokens,
    );
  }

  @override
  List<Object?> get props => [selected, progress, failure, uploadTokens];
}

/// Runs the three-request upload for the message being composed.
///
/// Kept separate from [ChatDetailController] on purpose: an upload can outlive
/// several composer edits, must survive a failed `sendMessage` (the tokens stay
/// valid, so retrying the send must not re-upload 50 MB), and is the only part
/// of the flow with meaningful progress to report.
class ChatAttachmentController
    extends AsyncNotifier<ChatAttachmentState, String> {
  StreamSubscription<void>? _subscription;

  @override
  ChatAttachmentState build(String arg) {
    ref.onDispose(() => _subscription?.cancel());
    return const ChatAttachmentState();
  }

  String get _chatId => arg;

  /// Validates a picked selection immediately (api-docs §6.5) so the user
  /// learns about an oversized file at pick time, not after a long upload.
  void select(List<AttachmentUploadRequestEntity> uploads) {
    final failure = ref
        .read(uploadChatAttachmentUseCaseProvider)
        .validate(uploads);

    state = ChatAttachmentState(
      selected: failure == null ? uploads : const [],
      failure: failure,
    );
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    state = const ChatAttachmentState();
  }

  /// Runs steps 1–3. On success [ChatAttachmentState.uploadTokens] is filled
  /// and the caller may send the message right away — no need to wait for the
  /// WS `attachment_success` event (api-docs §6.5).
  Future<void> upload() async {
    if (state.selected.isEmpty || state.isUploading) return;

    state = state.copyWith(clearFailure: true, uploadTokens: const []);

    final stream = ref
        .read(uploadChatAttachmentUseCaseProvider)
        .execute(_chatId, state.selected);

    await for (final event in stream) {
      event.match(
        (failure) {
          state = state.copyWith(failure: failure, clearProgress: true);
        },
        (progress) {
          state = state.copyWith(
            progress: progress,
            uploadTokens: progress.stage == ChatAttachmentUploadStage.done
                ? progress.uploadTokens
                : state.uploadTokens,
          );
        },
      );
      if (state.failure != null) return;
    }
  }
}

final chatAttachmentProvider =
    NotifierProvider.family<
      ChatAttachmentController,
      ChatAttachmentState,
      String
    >(ChatAttachmentController.new);
