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
///
/// An [AsyncNotifier] like every other controller in this feature, so screens
/// read one uniform `AsyncValue` shape throughout.
///
/// ⚠️ The upload deliberately never parks the provider in `AsyncValue.loading`.
/// Doing so would drop [ChatAttachmentState.selected] and
/// [ChatAttachmentState.progress] out of `state.value`, so the attachment bar
/// would blank out exactly while the progress bar is meant to be moving.
/// Progress is instead carried inside the data state, and
/// [ChatAttachmentState.isUploading] is the flag to render against.
///
/// A failed upload is also kept as *data* (`state.failure`) rather than
/// `AsyncValue.error`: the picked files must stay on screen so the user can
/// retry or drop them, which an error state cannot represent.
class ChatAttachmentController extends AsyncNotifier<ChatAttachmentState> {
  ChatAttachmentController(this._chatId);

  /// The chat this controller is scoped to. Riverpod 3's manual `family` API
  /// hands the argument to the constructor (there is no inherited `arg`).
  final String _chatId;

  /// Guards against a `clear()` (or a dispose) racing an in-flight upload:
  /// each run captures the generation it started in and stops writing state
  /// once it is superseded, so an abandoned batch can't repopulate the bar
  /// with tokens the user already dismissed.
  int _generation = 0;

  @override
  Future<ChatAttachmentState> build() async {
    ref.onDispose(() => _generation++);
    return const ChatAttachmentState();
  }

  /// Current data, or an empty selection while the (synchronous) first build
  /// hasn't landed yet.
  ChatAttachmentState get _current => state.value ?? const ChatAttachmentState();

  /// Validates a picked selection immediately (api-docs §6.5) so the user
  /// learns about an oversized file at pick time, not after a long upload.
  void select(List<AttachmentUploadRequestEntity> uploads) {
    _generation++;
    final failure = ref
        .read(uploadChatAttachmentUseCaseProvider)
        .validate(uploads);

    state = AsyncValue.data(
      ChatAttachmentState(
        selected: failure == null ? uploads : const [],
        failure: failure,
      ),
    );
  }

  void clear() {
    _generation++;
    state = const AsyncValue.data(ChatAttachmentState());
  }

  /// Runs steps 1–3. On success [ChatAttachmentState.uploadTokens] is filled
  /// and the caller may send the message right away — no need to wait for the
  /// WS `attachment_success` event (api-docs §6.5).
  Future<void> upload() async {
    final start = _current;
    if (start.selected.isEmpty || start.isUploading) return;

    final generation = _generation;
    state = AsyncValue.data(
      start.copyWith(clearFailure: true, uploadTokens: const []),
    );

    final stream = ref
        .read(uploadChatAttachmentUseCaseProvider)
        .execute(_chatId, start.selected);

    await for (final event in stream) {
      // Superseded by clear()/select() or disposed — stop touching state.
      if (generation != _generation) return;

      final current = _current;
      final next = event.match(
        (failure) => current.copyWith(failure: failure, clearProgress: true),
        (progress) => current.copyWith(
          progress: progress,
          uploadTokens: progress.stage == ChatAttachmentUploadStage.done
              ? progress.uploadTokens
              : current.uploadTokens,
        ),
      );
      state = AsyncValue.data(next);

      // The use case emits a single Left and closes, but returning here keeps
      // that contract from being load-bearing.
      if (next.failure != null) return;
    }
  }
}

final chatAttachmentProvider =
    AsyncNotifierProvider.family<
      ChatAttachmentController,
      ChatAttachmentState,
      String
    >(ChatAttachmentController.new);
