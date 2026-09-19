import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_chip.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The guidelines Flutter can check for us, run against the surfaces a
/// reader spends all their time on.
///
/// `androidTapTargetGuideline` is the 48dp rule, `iOSTapTargetGuideline` the
/// 44pt one, `labeledTapTargetGuideline` says nothing tappable may be
/// unnamed, and `textContrastGuideline` measures the pixels actually painted
/// rather than the tokens they came from — which is the only way to catch a
/// colour that was fine in the palette and wrong once it landed on a
/// gradient.
void main() {
  ChatProfileEntity profile(int userId, String name) => ChatProfileEntity(
    userId: userId,
    username: name.toLowerCase(),
    displayName: name,
    avatarUrl: null,
    avatarS3Key: null,
  );

  MessageEntity message({
    String id = 'm1',
    int seq = 1,
    int? authorId = 42,
    String? content = 'Same time tomorrow?',
    MessageType type = MessageType.text,
    bool isEdited = false,
  }) => MessageEntity(
    id: id,
    chatId: 'c',
    seq: seq,
    authorId: authorId,
    type: type,
    content: content,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: isEdited,
    createdAt: DateTime(2026, 1, 1, 14, 30),
    attachments: const [],
    profile: authorId == null ? null : profile(authorId, 'Ada'),
  );

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    required bool dark,
    double textScale = 1.0,
    TextDirection direction = TextDirection.ltr,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: direction,
            child: MediaQuery(
              data: MediaQueryData(
                textScaler: TextScaler.linear(textScale),
              ),
              // The real feed is a ListView; a fixed-height Column would
              // report overflow that the app never has.
              child: Scaffold(
                body: SingleChildScrollView(child: child),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    final theme = dark ? 'dark' : 'light';

    group('a conversation on the $theme theme', () {
      testWidgets('bubbles meet the contrast and labelling guidelines', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();

        await pump(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MessageBubble(
                message: message(),
                isMine: false,
                showAuthor: true,
                actions: const [MessageAction.reply],
                onReply: () {},
              ),
              MessageBubble(
                message: message(id: 'm2', seq: 2, isEdited: true),
                isMine: true,
                deliveryStatus: MessageDeliveryStatus.read,
                onShowDetails: () {},
              ),
            ],
          ),
          dark: dark,
        );

        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

        handle.dispose();
      });

      testWidgets('the composer is reachable by touch and by name', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);

        await pump(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              controller: controller,
              focusNode: focus,
              length: 0,
              hasAttachments: false,
              isRecording: false,
              isSending: false,
              slowMode: SlowMode.off,
              onAttach: () {},
              onSend: () {},
            ),
          ),
          dark: dark,
        );

        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));

        handle.dispose();
      });
    });
  }

  group('text that has been turned up', () {
    // A reader on the largest system setting is the one most likely to be
    // reading at all. Nothing may overflow, and the layout has to give.
    for (final scale in [1.3, 2.0]) {
      testWidgets('a bubble survives ${scale}x text', (tester) async {
        await pump(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MessageBubble(
                message: message(
                  content:
                      'A message long enough that it has to wrap more than '
                      'once, even before anybody turns the text up.',
                ),
                isMine: false,
                showAuthor: true,
                reactions: const MessageReactionsEntity(
                  messageId: 'm1',
                  groups: [
                    ReactionGroupEntity(
                      emoji: '👍',
                      count: 3,
                      reactedByMe: true,
                      recentUserIds: [1, 2, 3],
                    ),
                  ],
                ),
                onToggleReaction: (_) {},
                deliveryStatus: MessageDeliveryStatus.read,
              ),
            ],
          ),
          dark: false,
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('the composer survives ${scale}x text', (tester) async {
        final controller = TextEditingController(text: 'hello');
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);

        await pump(
          tester,
          Align(
            alignment: Alignment.bottomCenter,
            child: ChatComposer(
              controller: controller,
              focusNode: focus,
              length: 5,
              hasAttachments: false,
              isRecording: false,
              isSending: false,
              slowMode: SlowMode.off,
              onAttach: () {},
              onSend: () {},
            ),
          ),
          dark: false,
          textScale: scale,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  group('right to left', () {
    // ChatiX ships no RTL locale yet, but the layout must not fall over on
    // one: a bubble that is positioned with hard lefts and rights instead of
    // starts and ends breaks the moment somebody adds Arabic.
    testWidgets('a conversation lays out without overflowing', (tester) async {
      await pump(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MessageBubble(
              message: message(),
              isMine: false,
              showAuthor: true,
            ),
            MessageBubble(
              message: message(id: 'm2', seq: 2),
              isMine: true,
              deliveryStatus: MessageDeliveryStatus.sent,
            ),
          ],
        ),
        dark: false,
        direction: TextDirection.rtl,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the composer lays out without overflowing', (tester) async {
      final controller = TextEditingController(text: 'مرحبا');
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);

      await pump(
        tester,
        Align(
          alignment: Alignment.bottomCenter,
          child: ChatComposer(
            controller: controller,
            focusNode: focus,
            length: 5,
            hasAttachments: false,
            isRecording: false,
            isSending: false,
            slowMode: SlowMode.off,
            onAttach: () {},
            onSend: () {},
          ),
        ),
        dark: false,
        direction: TextDirection.rtl,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a reaction chip still reads and still has its tap', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();

      await pump(
        tester,
        Center(
          child: ReactionChip(emoji: '👍', count: 2, onTap: () {}),
        ),
        dark: false,
        direction: TextDirection.rtl,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getSemantics(find.byType(ReactionChip)).label,
        '👍, 2 reactions',
      );

      handle.dispose();
    });
  });
}
