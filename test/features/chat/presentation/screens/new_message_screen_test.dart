import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_people_screen.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_details_screen.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/new_chat_harness.dart';
import '../../../../helpers/pane_frame.dart';

/// "New message": a person is the choice — the chat with them opens, the
/// one that exists or, only when there is none, a new one.
void main() {
  final ru = AppLocalizationsRu();

  setUpAll(NewChatHarness.registerFallbacks);

  void verifyNothingCreated(NewChatHarness harness) {
    verifyNever(
      () => harness.createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    );
  }

  testWidgets('no "direct chat" to choose: people, and the ways in', (
    tester,
  ) async {
    await NewChatHarness().pump(tester, surface: const Size(390, 1400));

    expect(find.text(ru.newMessage), findsOneWidget);
    expect(find.text(ru.newGroup), findsOneWidget);
    expect(find.text(ru.newChannel), findsOneWidget);
    expect(find.text(ru.contactsAddAction), findsOneWidget);
    expect(find.text('Борис Петров'), findsOneWidget);
    // The old form's type switcher is gone.
    expect(find.byType(SegmentedButton<ChatType>), findsNothing);
    expect(find.text(ru.chatTypeDirect), findsNothing);
  });

  testWidgets('a person with a chat already: that chat opens, none is made', (
    tester,
  ) async {
    final harness = NewChatHarness(
      chats: [directChatWith('chat-boris', 2, name: 'Борис Петров')],
    );
    await harness.pump(tester, surface: const Size(390, 1400));

    await tester.tap(find.text('Борис Петров'));
    await tester.pumpAndSettle();

    expect(harness.opened, ['chat-boris']);
    expect(find.text('chat:chat-boris'), findsOneWidget);
    verifyNothingCreated(harness);
  });

  testWidgets('an archived chat with them opens too — never a second one', (
    tester,
  ) async {
    final harness = NewChatHarness();
    when(
      () =>
          harness.getChats.execute(limit: any(named: 'limit'), archived: true),
    ).thenAnswer(
      (_) async => Right(chatsPage([directChatWith('chat-archived', 2)])),
    );
    await harness.pump(tester, surface: const Size(390, 1400));

    await tester.tap(find.text('Борис Петров'));
    await tester.pumpAndSettle();

    expect(harness.opened, ['chat-archived']);
    verifyNothingCreated(harness);
  });

  testWidgets('nobody to find: one chat is made, even for a double tap', (
    tester,
  ) async {
    final harness = NewChatHarness()
      ..answerCreate((_) => Right(createdChat('chat-new', ChatType.direct)));
    await harness.pump(tester, surface: const Size(390, 1400));

    await tester.tap(find.text('Борис Петров'));
    await tester.tap(find.text('Борис Петров'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(harness.creates, hasLength(1));
    expect(harness.creates.single[#chatType], ChatType.direct);
    expect(harness.creates.single[#memberIds], [2]);
    expect(harness.opened, ['chat-new']);
  });

  testWidgets('a refusal is said in Russian, and nothing opens', (
    tester,
  ) async {
    final harness = NewChatHarness()
      ..answerCreate(
        (_) => const Left(
          ApiFailure(
            code: 'MESSAGES_PRIVACY_RESTRICTED',
            message: 'restricted',
            detail: {'chat_id': null, 'user_id': 2},
            status: 403,
          ),
        ),
      );
    await harness.pump(tester, surface: const Size(390, 1400));

    await tester.tap(find.text('Борис Петров'));
    await tester.pumpAndSettle();

    expect(find.text(ru.apiErrorMessagesPrivacyRestricted), findsOneWidget);
    expect(harness.opened, isEmpty);
  });

  testWidgets('typing searches the book, then everybody', (tester) async {
    final harness = NewChatHarness();
    await harness.pump(tester);

    await tester.enterText(find.byType(TextField), 'ann');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text(ru.contactsSectionMine.toUpperCase()), findsOneWidget);
    expect(find.text(ru.contactsSectionGlobal.toUpperCase()), findsOneWidget);
    // Ann Lee is nobody's contact: found by the global search.
    expect(find.text('Ann Lee'), findsOneWidget);
    // The ways in step aside while searching.
    expect(find.text(ru.newGroup), findsNothing);
  });

  testWidgets('"New group" and "New channel" open their first steps', (
    tester,
  ) async {
    final harness = NewChatHarness();
    await harness.pump(tester);

    await tester.tap(find.text(ru.newGroup));
    await tester.pumpAndSettle();
    expect(find.byType(NewChatPeopleScreen), findsOneWidget);

    harness.router.pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text(ru.newChannel));
    await tester.pumpAndSettle();
    expect(find.byType(NewChatDetailsScreen), findsOneWidget);
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('new message, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await NewChatHarness(
            directChats: const {1: 'chat-anna'},
            online: const {'chat-anna': true},
          ).pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'new_message_${window.name}_${theme.key}',
          );
        });

        testGoldens('new message search, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await NewChatHarness().pump(
            tester,
            window: window,
            dark: theme.value,
          );

          await tester.enterText(find.byType(TextField), 'ann');
          await tester.pump(const Duration(milliseconds: 400));
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'new_message_search_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
