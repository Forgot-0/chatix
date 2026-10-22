import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';

/// What the "new …" flow is making. There is no supergroup here: a new
/// group is a `group`, and growing past 500 is a setting of the group, not
/// a choice at birth (api-docs §5.1).
enum NewChatKind {
  group,
  channel;

  ChatType get chatType => switch (this) {
    NewChatKind.group => ChatType.group,
    NewChatKind.channel => ChatType.channel,
  };
}

/// Somebody picked for the new chat, with what their chip needs to draw.
class NewChatMember extends Equatable {
  const NewChatMember({
    required this.userId,
    required this.name,
    this.username,
    this.avatars = const <String, Map<String, String>>{},
  });

  final int userId;

  /// Already resolved the way every list resolves it: the name the reader
  /// saved them under, then their own, then their handle.
  final String name;

  final String? username;

  final Map<String, Map<String, String>> avatars;

  @override
  List<Object?> get props => [userId, name, username, avatars];
}

/// The picture chosen for the chat, already cropped and re-encoded on this
/// device — what goes up once the chat exists (api-docs §5.10).
class NewChatPhoto extends Equatable {
  const NewChatPhoto({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;

  @override
  List<Object?> get props => [mimeType, bytes.length, bytes];
}

/// Why a step will not let the reader go on.
enum NewChatProblem {
  /// More people than `POST /chats/` takes at once.
  tooManyMembers,

  /// A group or a channel needs a name; whitespace is not one.
  nameMissing,

  nameTooLong,
  descriptionTooLong,
}

/// The new group or channel as filled in so far.
///
/// Plain data with its own rules, so the steps can be checked without a
/// screen: the people step checks [membersProblem], the details step
/// [detailsProblem], and the final request is refused for [problem].
class NewChatDraft extends Equatable {
  const NewChatDraft({
    required this.kind,
    this.members = const <NewChatMember>[],
    this.name = '',
    this.description = '',
    this.photo,
    this.isPublic = false,
  });

  /// How many people `POST /chats/` takes in `member_ids` (api-docs §5.2).
  /// The rest are added from the chat once it exists.
  static const int maxMembers = CreateChatUseCase.maxInitialMembers;

  final NewChatKind kind;

  /// In the order they were picked, which is the order of the chips.
  final List<NewChatMember> members;

  final String name;
  final String description;
  final NewChatPhoto? photo;

  /// Only a channel asks; a new group starts private, as in Telegram, and
  /// can be opened up in its settings.
  final bool isPublic;

  List<int> get memberIds => [for (final member in members) member.userId];

  bool get isFull => members.length >= maxMembers;

  bool contains(int userId) => members.any((m) => m.userId == userId);

  /// [member] added — or taken out, when they were in already. Adding past
  /// [maxMembers] changes nothing: the step says why instead.
  NewChatDraft toggle(NewChatMember member) {
    if (contains(member.userId)) return remove(member.userId);
    if (isFull) return this;
    return copyWith(members: [...members, member]);
  }

  NewChatDraft remove(int userId) => copyWith(
    members: [
      for (final member in members)
        if (member.userId != userId) member,
    ],
  );

  /// Everyone in [userIds] taken out at once — the people the server said
  /// cannot be added (`USER_PRIVACY_RESTRICTED`).
  NewChatDraft without(Iterable<int> userIds) {
    final drop = userIds.toSet();
    return copyWith(
      members: [
        for (final member in members)
          if (!drop.contains(member.userId)) member,
      ],
    );
  }

  NewChatProblem? get membersProblem =>
      members.length > maxMembers ? NewChatProblem.tooManyMembers : null;

  NewChatProblem? get detailsProblem {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return NewChatProblem.nameMissing;
    if (trimmed.length > CreateChatUseCase.maxNameLength) {
      return NewChatProblem.nameTooLong;
    }
    if (description.trim().length > CreateChatUseCase.maxDescriptionLength) {
      return NewChatProblem.descriptionTooLong;
    }
    return null;
  }

  /// The first thing wrong with the whole draft, or null.
  NewChatProblem? get problem => membersProblem ?? detailsProblem;

  NewChatDraft copyWith({
    List<NewChatMember>? members,
    String? name,
    String? description,
    NewChatPhoto? Function()? photo,
    bool? isPublic,
  }) {
    return NewChatDraft(
      kind: kind,
      members: members ?? this.members,
      name: name ?? this.name,
      description: description ?? this.description,
      photo: photo == null ? this.photo : photo(),
      isPublic: isPublic ?? this.isPublic,
    );
  }

  @override
  List<Object?> get props => [
    kind,
    members,
    name,
    description,
    photo,
    isPublic,
  ];
}
