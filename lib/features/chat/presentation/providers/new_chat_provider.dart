import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';

/// The flow's draft, and whether the create is on the wire.
class NewChatState extends Equatable {
  const NewChatState({required this.draft, this.isSubmitting = false});

  final NewChatDraft draft;
  final bool isSubmitting;

  NewChatState copyWith({NewChatDraft? draft, bool? isSubmitting}) {
    return NewChatState(
      draft: draft ?? this.draft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }

  @override
  List<Object?> get props => [draft, isSubmitting];
}

/// A step refused to go on; the screen names [problem] in its own words.
class NewChatValidationFailure extends Failure {
  const NewChatValidationFailure(this.problem)
    : super(message: 'The new chat is not ready to be created');

  final NewChatProblem problem;

  @override
  List<Object?> get props => [...super.props, problem];
}

/// What a create that went through hands back.
class NewChatCreated extends Equatable {
  const NewChatCreated({
    required this.chatId,
    this.notAdded = const <NewChatMember>[],
    this.photoFailed = false,
  });

  final String chatId;

  /// People the server would not let in — their `group_invites` privacy or
  /// a block (`USER_PRIVACY_RESTRICTED`, api-docs §4.14). The chat was made
  /// without them, as Telegram does, and the reader is told who.
  final List<NewChatMember> notAdded;

  /// The chat exists but its picture did not go up; it can be set again
  /// from the chat's settings.
  final bool photoFailed;

  @override
  List<Object?> get props => [chatId, notAdded, photoFailed];
}

/// One "new group" or "new channel" flow, from the first step to the chat.
///
/// Every step of the flow watches the same instance, so going back and
/// forth keeps what was typed; leaving the flow altogether drops it.
class NewChatController extends Notifier<NewChatState> {
  NewChatController(this.kind);

  final NewChatKind kind;

  @override
  NewChatState build() => NewChatState(draft: NewChatDraft(kind: kind));

  NewChatDraft get _draft => state.draft;

  void _edit(NewChatDraft draft) {
    if (state.isSubmitting) return;
    state = state.copyWith(draft: draft);
  }

  void toggle(NewChatMember member) => _edit(_draft.toggle(member));

  void remove(int userId) => _edit(_draft.remove(userId));

  void setName(String value) => _edit(_draft.copyWith(name: value));

  void setDescription(String value) =>
      _edit(_draft.copyWith(description: value));

  void setPhoto(NewChatPhoto? photo) =>
      _edit(_draft.copyWith(photo: () => photo));

  void setPublic(bool value) => _edit(_draft.copyWith(isPublic: value));

  /// Creates the chat, then sends its picture.
  ///
  /// When the server refuses some of the people (`USER_PRIVACY_RESTRICTED`)
  /// the chat is made once more without them rather than not at all — the
  /// whole request fails otherwise, and those people could not have been
  /// added anyway.
  Future<Either<Failure, NewChatCreated>> submit() async {
    if (state.isSubmitting) return const Left(CancelledFailure());

    final draft = _draft;
    final problem = draft.problem;
    if (problem != null) return Left(NewChatValidationFailure(problem));

    state = state.copyWith(isSubmitting: true);

    var members = draft.members;
    var created = await _create(draft, members);
    if (!ref.mounted) return const Left(CancelledFailure());

    final refused = _refusedUserIds(created);
    final notAdded = [
      for (final member in members)
        if (refused.contains(member.userId)) member,
    ];
    if (notAdded.isNotEmpty) {
      members = draft.without(refused).members;
      created = await _create(draft, members);
      if (!ref.mounted) return const Left(CancelledFailure());
    }

    final failure = created.getLeft().toNullable();
    if (failure != null) {
      state = state.copyWith(isSubmitting: false);
      return Left(failure);
    }

    final chat = created.getRight().toNullable()!;
    ref.read(chatListProvider.notifier).adoptRow(chat);

    var photoFailed = false;
    final photo = draft.photo;
    if (photo != null) {
      final uploaded = await ref
          .read(uploadChatAvatarUseCaseProvider)
          .execute(chat.id, bytes: photo.bytes, mimeType: photo.mimeType);
      photoFailed = uploaded.isLeft();
    }

    // Left as submitting: the screen leaves for the chat now, and the
    // buttons should not come back to life on the way out.
    return Right(
      NewChatCreated(
        chatId: chat.id,
        notAdded: notAdded,
        photoFailed: photoFailed,
      ),
    );
  }

  Future<Either<Failure, ChatEntity>> _create(
    NewChatDraft draft,
    List<NewChatMember> members,
  ) {
    final description = draft.description.trim();
    return ref
        .read(createChatUseCaseProvider)
        .execute(
          name: draft.name.trim(),
          description: description.isEmpty ? null : description,
          chatType: kind.chatType,
          memberIds: [for (final member in members) member.userId],
          isPublic: kind == NewChatKind.channel && draft.isPublic,
        );
  }

  /// The `user_ids` of a `403 USER_PRIVACY_RESTRICTED`, or nothing.
  static Set<int> _refusedUserIds(Either<Failure, ChatEntity> result) {
    final failure = result.getLeft().toNullable();
    if (failure is! ApiFailure || failure.code != 'USER_PRIVACY_RESTRICTED') {
      return const <int>{};
    }
    final detail = failure.detail;
    final ids = detail is Map ? detail['user_ids'] : null;
    if (ids is! List) return const <int>{};
    return {
      for (final id in ids)
        if (id is num) id.toInt(),
    };
  }
}

final newGroupProvider =
    NotifierProvider.autoDispose<NewChatController, NewChatState>(
      () => NewChatController(NewChatKind.group),
    );

final newChannelProvider =
    NotifierProvider.autoDispose<NewChatController, NewChatState>(
      () => NewChatController(NewChatKind.channel),
    );

/// The flow's provider for [kind].
NotifierProvider<NewChatController, NewChatState> newChatProviderOf(
  NewChatKind kind,
) => switch (kind) {
  NewChatKind.group => newGroupProvider,
  NewChatKind.channel => newChannelProvider,
};
