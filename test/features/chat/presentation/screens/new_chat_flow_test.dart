import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/new_chat_provider.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_details_screen.dart';
import 'package:chatix/features/chat/presentation/screens/new_chat_people_screen.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/new_chat_harness.dart';
import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/test_photos.dart';

/// "New group" and "New channel", step by step.
void main() {
  final ru = AppLocalizationsRu();
  final photo = NewChatPhoto(
    bytes: TestPhotos.encode(96, 96, palette: 4),
    mimeType: 'image/png',
  );

  setUpAll(NewChatHarness.registerFallbacks);

  setUp(() => EditableText.debugDeterministicCursor = true);
  tearDown(() => EditableText.debugDeterministicCursor = false);

  Finder chipOf(String name) =>
      find.bySemanticsLabel(ru.newChatRemoveMember(name));

  /// Picks for the group by tapping rows, as the reader does.
  Future<void> pick(WidgetTester tester, List<String> names) async {
    for (final name in names) {
      await tester.tap(find.text(name).last);
      await tester.pumpAndSettle();
    }
  }

  /// Lets a picked photo decode, which only happens on the real event loop.
  Future<void> settlePhoto(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }

  group('new group — people', () {
    testWidgets('a tap picks, the chip shows, a tap on the chip un-picks', (
      tester,
    ) async {
      await NewChatHarness().pump(tester, location: NewGroupRoute.location);

      expect(find.text(ru.newGroupMembersTitle), findsOneWidget);
      expect(find.text(ru.newChatMembersCount(0, 100)), findsOneWidget);
      expect(find.text(ru.newChatMembersLimitHint(100)), findsOneWidget);

      await pick(tester, ['Борис Петров']);

      expect(chipOf('Борис Петров'), findsOneWidget);
      expect(find.text(ru.newChatMembersCount(1, 100)), findsOneWidget);

      await tester.tap(chipOf('Борис Петров'));
      await tester.pumpAndSettle();

      expect(chipOf('Борис Петров'), findsNothing);
      expect(find.text(ru.newChatMembersCount(0, 100)), findsOneWidget);
    });

    testWidgets('a second tap on a row takes the person out again', (
      tester,
    ) async {
      final harness = NewChatHarness();
      await harness.pump(tester, location: NewGroupRoute.location);

      await pick(tester, ['Борис Петров', 'Борис Петров']);

      expect(chipOf('Борис Петров'), findsNothing);
      expect(harness.container.read(newGroupProvider).draft.members, isEmpty);
    });

    testWidgets('at the limit, one more is refused and the hint says why', (
      tester,
    ) async {
      final harness = NewChatHarness();
      await harness.pump(tester, location: NewGroupRoute.location);

      final flow = harness.container.read(newGroupProvider.notifier);
      for (var id = 1000; id < 1000 + NewChatDraft.maxMembers; id++) {
        flow.toggle(NewChatMember(userId: id, name: 'P$id'));
      }
      await tester.pumpAndSettle();

      expect(find.text(ru.newChatMembersCount(100, 100)), findsOneWidget);
      expect(find.text(ru.newChatMembersLimitReached(100)), findsOneWidget);

      await tester.tap(find.text('Борис Петров'));
      await tester.pump();

      // The caption, and the toast for the tap.
      expect(find.text(ru.newChatMembersLimitReached(100)), findsNWidgets(2));
      expect(
        harness.container.read(newGroupProvider).draft.contains(2),
        isFalse,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('searching finds people outside the book; a pick clears it', (
      tester,
    ) async {
      final harness = NewChatHarness();
      await harness.pump(tester, location: NewGroupRoute.location);

      await tester.enterText(find.byType(TextField), 'ann');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ann Lee'));
      await tester.pumpAndSettle();

      expect(chipOf('Ann Lee'), findsOneWidget);
      expect(harness.container.read(newGroupProvider).draft.memberIds, [30]);
      // Back to the book for the next pick.
      expect(find.text(ru.contactsSectionGlobal.toUpperCase()), findsNothing);
    });

    testWidgets(
      '"Next" on the right of the app bar, and the arrow on a phone',
      (tester) async {
        await NewChatHarness().pump(tester, location: NewGroupRoute.location);

        expect(find.widgetWithText(TextButton, ru.next), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
      },
    );

    testWidgets('no round button where the pane is wide', (tester) async {
      await NewChatHarness().pump(
        tester,
        location: NewGroupRoute.location,
        window: PaneWindow.desktop,
      );

      expect(find.widgetWithText(TextButton, ru.next), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('nobody picked is allowed: "Next" still goes on', (
      tester,
    ) async {
      final harness = NewChatHarness();
      await harness.pump(tester, location: NewGroupRoute.location);

      await harness.tapAppBarAction(tester, ru.next);

      expect(find.byType(NewChatDetailsScreen), findsOneWidget);
      expect(find.text(ru.newGroupNoMembers), findsOneWidget);
    });
  });

  group('new group — details', () {
    testWidgets('no name, no group: the field says so and nothing is sent', (
      tester,
    ) async {
      final harness = NewChatHarness();
      await harness.pump(tester, location: NewGroupDetailsRoute.location);

      await harness.tapAppBarAction(tester, ru.create);

      expect(find.text(ru.newGroupNameRequired), findsOneWidget);
      expect(harness.creates, isEmpty);
    });

    testWidgets('a whole run: people, a name, a photo — and into the chat', (
      tester,
    ) async {
      final harness = NewChatHarness()
        ..pickedPhoto = photo
        ..answerCreate((_) => Right(createdChat('group-1', ChatType.group)));
      await harness.pump(tester, location: NewGroupRoute.location);

      await pick(tester, ['Анна Смирнова', 'Борис Петров']);
      await harness.tapAppBarAction(tester, ru.next);

      // Who it starts with, under the form.
      expect(find.text(ru.membersCount(2).toUpperCase()), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(ru.chatPhotoAdd));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.choosePhoto));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(ru.changePhoto), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, ru.newGroupNameLabel),
        '  Релиз 2.0 ',
      );
      await tester.enterText(
        find.widgetWithText(TextField, ru.newChatDescriptionLabel),
        'Всё о выпуске',
      );
      await harness.tapAppBarAction(tester, ru.create);

      final call = harness.creates.single;
      expect(call[#chatType], ChatType.group);
      expect(call[#name], 'Релиз 2.0');
      expect(call[#description], 'Всё о выпуске');
      expect(call[#memberIds], [1, 2]);
      expect(call[#isPublic], isFalse);
      verify(
        () => harness.uploadAvatar.execute(
          'group-1',
          bytes: photo.bytes,
          mimeType: 'image/png',
        ),
      ).called(1);
      expect(harness.opened, ['group-1']);
    });

    testWidgets(
      'people whose privacy keeps them out: made without, and named',
      (tester) async {
        final harness = NewChatHarness();
        var attempt = 0;
        harness.answerCreate((_) {
          attempt++;
          if (attempt == 1) {
            return const Left(
              ApiFailure(
                code: 'USER_PRIVACY_RESTRICTED',
                message: 'restricted',
                detail: {
                  'user_ids': [2],
                },
                status: 403,
              ),
            );
          }
          return Right(createdChat('group-2', ChatType.group));
        });
        await harness.pump(tester, location: NewGroupRoute.location);

        await pick(tester, ['Анна Смирнова', 'Борис Петров']);
        await harness.tapAppBarAction(tester, ru.next);
        await tester.enterText(
          find.widgetWithText(TextField, ru.newGroupNameLabel),
          'Релиз',
        );
        await harness.tapAppBarAction(tester, ru.create);

        expect(harness.creates.map((c) => c[#memberIds]), [
          [1, 2],
          [1],
        ]);
        expect(harness.opened, ['group-2']);
        expect(
          find.text(ru.newChatSomeNotAdded('Борис Петров')),
          findsOneWidget,
        );
      },
    );

    testWidgets('a refusal stays on the step, said in Russian', (tester) async {
      final harness = NewChatHarness()
        ..answerCreate((_) => const Left(RateLimitFailure()));
      await harness.pump(tester, location: NewGroupDetailsRoute.location);

      await tester.enterText(
        find.widgetWithText(TextField, ru.newGroupNameLabel),
        'Релиз',
      );
      await harness.tapAppBarAction(tester, ru.create);

      expect(find.text(ru.failureRateLimited), findsOneWidget);
      expect(harness.opened, isEmpty);
      // Still there to try again.
      expect(find.widgetWithText(TextButton, ru.create), findsOneWidget);
    });

    testWidgets('going back to the people keeps what was typed', (
      tester,
    ) async {
      final harness = NewChatHarness();
      await harness.pump(tester, location: NewGroupRoute.location);

      await harness.tapAppBarAction(tester, ru.next);
      await tester.enterText(
        find.widgetWithText(TextField, ru.newGroupNameLabel),
        'Релиз',
      );
      harness.router.pop();
      await tester.pumpAndSettle();
      await harness.tapAppBarAction(tester, ru.next);

      expect(find.text('Релиз'), findsOneWidget);
    });
  });

  group('new channel', () {
    testWidgets('public or private, each said in plain words', (tester) async {
      await NewChatHarness().pump(tester, location: NewChannelRoute.location);

      expect(find.text(ru.newChannelPrivate), findsOneWidget);
      expect(find.text(ru.newChannelPrivateHint), findsOneWidget);
      expect(find.text(ru.newChannelPublic), findsOneWidget);
      expect(find.text(ru.newChannelPublicHint), findsOneWidget);
      // No permission names, no slow mode, no supergroup here.
      expect(find.textContaining('message:'), findsNothing);
      expect(find.textContaining('упергрупп'), findsNothing);
    });

    testWidgets('details, then optional subscribers, then the channel', (
      tester,
    ) async {
      final harness = NewChatHarness()
        ..answerCreate(
          (_) => Right(createdChat('channel-1', ChatType.channel)),
        );
      await harness.pump(tester, location: NewChannelRoute.location);

      await harness.tapAppBarAction(tester, ru.next);
      expect(find.text(ru.newChannelNameRequired), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, ru.newChannelNameLabel),
        'Новости',
      );
      await tester.tap(find.text(ru.newChannelPublic));
      await tester.pumpAndSettle();
      await harness.tapAppBarAction(tester, ru.next);

      expect(find.byType(NewChatPeopleScreen), findsOneWidget);
      expect(find.text(ru.newChannelSubscribersTitle), findsOneWidget);
      expect(find.text(ru.newChannelSubscribersHint(100)), findsOneWidget);

      // Nobody picked: subscribers are optional.
      await harness.tapAppBarAction(tester, ru.create);

      final call = harness.creates.single;
      expect(call[#chatType], ChatType.channel);
      expect(call[#name], 'Новости');
      expect(call[#isPublic], isTrue);
      expect(call[#memberIds], isEmpty);
      expect(harness.opened, ['channel-1']);
    });

    testWidgets('a channel is private unless the reader says otherwise', (
      tester,
    ) async {
      final harness = NewChatHarness()
        ..answerCreate(
          (_) => Right(createdChat('channel-2', ChatType.channel)),
        );
      await harness.pump(tester, location: NewChannelRoute.location);

      await tester.enterText(
        find.widgetWithText(TextField, ru.newChannelNameLabel),
        'Закрытый',
      );
      await harness.tapAppBarAction(tester, ru.next);
      await pick(tester, ['Борис Петров']);
      await harness.tapAppBarAction(tester, ru.create);

      final call = harness.creates.single;
      expect(call[#isPublic], isFalse);
      expect(call[#memberIds], [2]);
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        final suffix = '${window.name}_${theme.key}';

        testGoldens('group people, $suffix', (tester) async {
          await NewChatHarness(
            directChats: const {1: 'chat-anna'},
            online: const {'chat-anna': true},
          ).pump(
            tester,
            location: NewGroupRoute.location,
            window: window,
            dark: theme.value,
          );
          await pick(tester, ['Анна Смирнова', 'Борис Петров', 'Ваня Работа']);

          await screenMatchesGolden(tester, 'new_group_people_$suffix');
        });

        testGoldens('group details, $suffix', (tester) async {
          final harness = NewChatHarness()..pickedPhoto = photo;
          await harness.pump(
            tester,
            location: NewGroupRoute.location,
            window: window,
            dark: theme.value,
          );
          await pick(tester, ['Анна Смирнова', 'Борис Петров']);
          await harness.tapAppBarAction(tester, ru.next);

          await tester.tap(find.bySemanticsLabel(ru.chatPhotoAdd));
          await tester.pumpAndSettle();
          await tester.tap(find.text(ru.choosePhoto));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, ru.newGroupNameLabel),
            'Релиз 2.0',
          );
          await tester.pumpAndSettle();
          await settlePhoto(tester);

          await screenMatchesGolden(
            tester,
            'new_group_details_$suffix',
            customPump: (tester) => tester.pump(),
          );
        });

        testGoldens('group details, no name, $suffix', (tester) async {
          final harness = NewChatHarness();
          await harness.pump(
            tester,
            location: NewGroupDetailsRoute.location,
            window: window,
            dark: theme.value,
          );
          await harness.tapAppBarAction(tester, ru.create);

          await screenMatchesGolden(tester, 'new_group_details_error_$suffix');
        });

        testGoldens('channel details, $suffix', (tester) async {
          await NewChatHarness().pump(
            tester,
            location: NewChannelRoute.location,
            window: window,
            dark: theme.value,
          );
          await tester.enterText(
            find.widgetWithText(TextField, ru.newChannelNameLabel),
            'Новости ChatiX',
          );
          await tester.enterText(
            find.widgetWithText(TextField, ru.newChatDescriptionLabel),
            'Что нового в приложении',
          );
          await tester.tap(find.text(ru.newChannelPublic));
          await tester.pumpAndSettle();

          await screenMatchesGolden(tester, 'new_channel_details_$suffix');
        });

        testGoldens('channel subscribers, $suffix', (tester) async {
          final harness = NewChatHarness();
          await harness.pump(
            tester,
            location: NewChannelRoute.location,
            window: window,
            dark: theme.value,
          );
          await tester.enterText(
            find.widgetWithText(TextField, ru.newChannelNameLabel),
            'Новости',
          );
          await harness.tapAppBarAction(tester, ru.next);
          await pick(tester, ['Борис Петров']);

          await screenMatchesGolden(tester, 'new_channel_subscribers_$suffix');
        });
      }
    }
  });
}
