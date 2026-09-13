import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_attachment_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class ChatAttachmentState extends Equatable {
  final List<AttachmentUploadRequestEntity> selected;

  final ChatAttachmentUploadProgress? progress;
  final Failure? failure;

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

class ChatAttachmentController extends AsyncNotifier<ChatAttachmentState> {
  ChatAttachmentController(this._chatId);

  final String _chatId;

  int _generation = 0;

  /// The handle on the transfer in flight, so the tray's cancel button has
  /// something to pull.
  TransferCancellation? _transfer;

  @override
  Future<ChatAttachmentState> build() async {
    ref.onDispose(() => _generation++);
    return const ChatAttachmentState();
  }

  ChatAttachmentState get _current =>
      state.value ?? const ChatAttachmentState();

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

  /// Drops one file from the selection, keeping the rest.
  ///
  /// Only meaningful before the upload starts — once slots are requested
  /// they are per file and in order (api-docs §5.5), so a selection that
  /// changes under way starts over.
  void removeAt(int index) {
    final selected = _current.selected;
    if (index < 0 || index >= selected.length) return;

    _transfer?.cancel();
    _transfer = null;
    _generation++;

    final next = [...selected]..removeAt(index);
    state = AsyncValue.data(ChatAttachmentState(selected: next));
  }

  Future<void> upload() async {
    final start = _current;
    if (start.selected.isEmpty || start.isUploading) return;

    final generation = _generation;
    final transfer = TransferCancellation();
    _transfer = transfer;

    state = AsyncValue.data(
      start.copyWith(clearFailure: true, uploadTokens: const []),
    );

    final stream = ref
        .read(uploadChatAttachmentUseCaseProvider)
        .execute(_chatId, start.selected, cancellation: transfer);

    await for (final event in stream) {
      if (generation != _generation) return;

      final current = _current;
      final next = event.match(
        // A cancelled transfer is not a failure to report: the person who
        // stopped it knows why, and [cancel] has already cleared the tray.
        (failure) => failure is CancelledFailure
            ? current.copyWith(clearProgress: true)
            : current.copyWith(failure: failure, clearProgress: true),
        (progress) => current.copyWith(
          progress: progress,
          uploadTokens: progress.stage == ChatAttachmentUploadStage.done
              ? progress.uploadTokens
              : current.uploadTokens,
        ),
      );
      state = AsyncValue.data(next);

      if (next.failure != null) break;
    }

    if (identical(_transfer, transfer)) _transfer = null;
  }

  /// Stops an upload in flight and empties the tray.
  ///
  /// The slots already requested are simply abandoned: there is no endpoint
  /// to hand an `upload_token` back with (api-docs §5.5), and one never
  /// confirmed is never attached to anything.
  void cancel() {
    _transfer?.cancel();
    _transfer = null;
    clear();
  }

  /// Runs the same selection again after a failure.
  Future<void> retry() async {
    final selected = _current.selected;
    if (selected.isEmpty) return;

    _generation++;
    state = AsyncValue.data(
      ChatAttachmentState(selected: selected),
    );

    await upload();
  }
}

final chatAttachmentProvider =
    AsyncNotifierProvider.family<
      ChatAttachmentController,
      ChatAttachmentState,
      String
    >(ChatAttachmentController.new);
