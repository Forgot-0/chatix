import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
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
