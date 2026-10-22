import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';

/// What each step of "new group" / "new channel" lets through.
void main() {
  NewChatMember person(int id) => NewChatMember(userId: id, name: 'P$id');

  NewChatDraft groupWith(int people) => NewChatDraft(
    kind: NewChatKind.group,
    members: [for (var id = 1; id <= people; id++) person(id)],
  );

  group('the people step', () {
    test('nobody picked is fine: people can come later', () {
      expect(groupWith(0).membersProblem, isNull);
    });

    test('a tap adds, a second tap on the same person takes out', () {
      final once = groupWith(0).toggle(person(5));
      expect(once.memberIds, [5]);

      final twice = once.toggle(person(5));
      expect(twice.memberIds, isEmpty);
    });

    test('picks keep the order they were made in — the chips do', () {
      final draft = groupWith(
        0,
      ).toggle(person(3)).toggle(person(1)).toggle(person(2));
      expect(draft.memberIds, [3, 1, 2]);
    });

    test('the limit is what POST /chats/ takes at once', () {
      expect(NewChatDraft.maxMembers, CreateChatUseCase.maxInitialMembers);
      expect(NewChatDraft.maxMembers, 100);
    });

    test('a full draft takes nobody else, and says it is full', () {
      final full = groupWith(NewChatDraft.maxMembers);
      expect(full.isFull, isTrue);
      expect(full.membersProblem, isNull);

      final tried = full.toggle(person(1000));
      expect(tried, full);
    });

    test('a full draft still lets someone go', () {
      final full = groupWith(NewChatDraft.maxMembers);
      final fewer = full.toggle(person(1));

      expect(fewer.isFull, isFalse);
      expect(fewer.contains(1), isFalse);
    });

    test('over the limit — only reachable by hand — is refused', () {
      final over = NewChatDraft(
        kind: NewChatKind.group,
        members: [
          for (var id = 1; id <= NewChatDraft.maxMembers + 1; id++) person(id),
        ],
      );
      expect(over.membersProblem, NewChatProblem.tooManyMembers);
      expect(over.problem, NewChatProblem.tooManyMembers);
    });

    test('the people the server refused can be dropped in one go', () {
      final draft = groupWith(4).without({2, 4, 99});
      expect(draft.memberIds, [1, 3]);
    });
  });

  group('the details step', () {
    test('a name is the one thing it cannot go without', () {
      final draft = groupWith(2);
      expect(draft.detailsProblem, NewChatProblem.nameMissing);
      expect(draft.problem, NewChatProblem.nameMissing);
    });

    test('whitespace is not a name', () {
      expect(
        groupWith(0).copyWith(name: '   ').detailsProblem,
        NewChatProblem.nameMissing,
      );
    });

    test('a name and nothing else is enough', () {
      final draft = groupWith(0).copyWith(name: 'Release');
      expect(draft.detailsProblem, isNull);
      expect(draft.problem, isNull);
    });

    test('names and descriptions keep to the server limits', () {
      expect(
        groupWith(0)
            .copyWith(name: 'x' * (CreateChatUseCase.maxNameLength + 1))
            .detailsProblem,
        NewChatProblem.nameTooLong,
      );
      expect(
        groupWith(0)
            .copyWith(
              name: 'Release',
              description: 'x' * (CreateChatUseCase.maxDescriptionLength + 1),
            )
            .detailsProblem,
        NewChatProblem.descriptionTooLong,
      );
    });

    test('the limits are measured on what would be sent — trimmed', () {
      final padded = '  ${'x' * CreateChatUseCase.maxNameLength}  ';
      expect(groupWith(0).copyWith(name: padded).detailsProblem, isNull);
    });

    test('a photo can be set and taken away again', () {
      final photo = NewChatPhoto(
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );
      final withPhoto = groupWith(0).copyWith(photo: () => photo);
      expect(withPhoto.photo, photo);
      expect(withPhoto.copyWith(photo: () => null).photo, isNull);
      // Other edits leave it be.
      expect(withPhoto.copyWith(name: 'A').photo, photo);
    });
  });

  test('the kinds map onto the API types — never a supergroup', () {
    expect(NewChatKind.group.chatType, ChatType.group);
    expect(NewChatKind.channel.chatType, ChatType.channel);
    expect(
      NewChatKind.values.map((kind) => kind.chatType),
      isNot(contains(ChatType.supergroup)),
    );
  });
}
