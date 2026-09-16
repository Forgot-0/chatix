import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_settings_draft.dart';

/// `PATCH /chats/{chat_id}/` is a real partial update: a field left out of
/// the body stays as it was, and `null` never means "unset" (api-docs §5.2).
/// So what matters is that a save carries exactly what the reader changed.
void main() {
  ChatEntity chat({
    String? name = 'Team',
    String? description = 'About us',
    bool isPublic = false,
    bool adminOnly = false,
    int slowMode = 0,
    ChatReactionsMode reactionsMode = ChatReactionsMode.all,
    List<String> allowed = const [],
  }) => ChatEntity(
    id: 'c1',
    seqCounter: 1,
    lastActivityAt: null,
    type: ChatType.group,
    name: name,
    description: description,
    avatarS3Key: null,
    isPublic: isPublic,
    adminOnly: adminOnly,
    slowModeSeconds: slowMode,
    permissions: const {},
    reactionsMode: reactionsMode,
    allowedReactions: allowed,
    createdBy: 1,
    memberCount: 3,
  );

  ChatSettingsDraft draftOf(
    ChatEntity source, {
    String? name,
    String? description,
    bool? isPublic,
    bool? adminOnly,
    String? slowMode,
    ChatReactionsMode? reactionsMode,
    Set<String>? allowed,
  }) => ChatSettingsDraft(
    name: name ?? source.name ?? '',
    description: description ?? source.description ?? '',
    isPublic: isPublic ?? source.isPublic,
    adminOnly: adminOnly ?? source.adminOnly,
    slowMode: slowMode ?? '${source.slowModeSeconds}',
    reactionsMode: reactionsMode ?? source.reactionsMode,
    allowedReactions: allowed ?? source.allowedReactions.toSet(),
  );

  group('what a save sends', () {
    test('an untouched form has nothing to send', () {
      final source = chat();

      expect(draftOf(source).diff(source).isEmpty, isTrue);
    });

    test('only the field that changed travels', () {
      final source = chat();
      final patch = draftOf(source, description: 'Something else').diff(source);

      expect(patch.description, 'Something else');
      expect(patch.name, isNull);
      expect(patch.isPublic, isNull);
      expect(patch.adminOnly, isNull);
      expect(patch.slowModeSeconds, isNull);
      expect(patch.reactionsMode, isNull);
      expect(patch.allowedReactions, isNull);
    });

    test('a switch turned off is sent as false, not left out', () {
      final source = chat(isPublic: true);
      final patch = draftOf(source, isPublic: false).diff(source);

      expect(patch.isPublic, isFalse);
    });

    test('whitespace around a name is not a change', () {
      final source = chat(name: 'Team');

      expect(draftOf(source, name: '  Team  ').diff(source).name, isNull);
    });

    test('a description can be emptied, because that is a value', () {
      final source = chat(description: 'About us');

      expect(draftOf(source, description: '').diff(source).description, '');
    });

    test('slow mode travels as a number', () {
      final source = chat(slowMode: 0);
      final patch = draftOf(source, slowMode: '30').diff(source);

      expect(patch.slowModeSeconds, 30);
    });
  });

  group('reactions', () {
    test('the white list only travels under "some"', () {
      final source = chat(
        reactionsMode: ChatReactionsMode.some,
        allowed: const ['👍'],
      );

      final patch = draftOf(
        source,
        reactionsMode: ChatReactionsMode.all,
        allowed: const {'👍', '🔥'},
      ).diff(source);

      expect(patch.reactionsMode, ChatReactionsMode.all);
      expect(patch.allowedReactions, isNull);
    });

    test('a changed white list travels in catalog order', () {
      final source = chat(
        reactionsMode: ChatReactionsMode.some,
        allowed: const ['👍'],
      );

      final patch = draftOf(source, allowed: const {'🔥', '👍'}).diff(source);

      expect(patch.allowedReactions, ['👍', '🔥']);
      expect(patch.reactionsMode, isNull);
    });

    test('the same white list in a different order is not a change', () {
      final source = chat(
        reactionsMode: ChatReactionsMode.some,
        allowed: const ['🔥', '👍'],
      );

      expect(
        draftOf(source, allowed: const {'👍', '🔥'}).diff(source).isEmpty,
        isTrue,
      );
    });
  });

  group('what a save refuses', () {
    test('a name cannot be cleared, because the API cannot unset one', () {
      final source = chat(name: 'Team');

      expect(
        draftOf(source, name: '   ').validate(source),
        ChatSettingsError.nameCleared,
      );
    });

    test('a chat that never had a name may stay nameless', () {
      final source = chat(name: null);

      expect(draftOf(source, name: '').validate(source), isNull);
    });

    test('slow mode outside 0..86400 is refused', () {
      final source = chat();

      expect(
        draftOf(source, slowMode: '86401').validate(source),
        ChatSettingsError.slowModeOutOfRange,
      );
      expect(draftOf(source, slowMode: '86400').validate(source), isNull);
    });

    test('a slow mode that is not a number is refused', () {
      final source = chat();

      expect(
        draftOf(source, slowMode: '').validate(source),
        ChatSettingsError.slowModeOutOfRange,
      );
    });

    test('"some" with nothing picked would turn reactions off sideways', () {
      final source = chat();

      expect(
        draftOf(
          source,
          reactionsMode: ChatReactionsMode.some,
          allowed: const {},
        ).validate(source),
        ChatSettingsError.noReactionsPicked,
      );
    });
  });
}
