import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_effects.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A reaction lands before the server has answered, so the motion is what
/// tells the reader the tap registered: the chip blooms, and the message's
/// very first reaction throws particles.
void main() {
  MessageEntity message({List<ReactionGroupEntity> reactions = const []}) =>
      MessageEntity(
        id: 'm1',
        chatId: 'c',
        seq: 1,
        authorId: 42,
        type: MessageType.text,
        content: 'hello',
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime(2026, 1, 1, 14, 30),
        attachments: const [],
        reactions: reactions,
      );

  MessageReactionsEntity summary(List<String> emojis) => MessageReactionsEntity(
    messageId: 'm1',
    groups: [
      for (final emoji in emojis) ReactionGroupEntity(emoji: emoji, count: 1),
    ],
  );

  Future<void> pump(
    WidgetTester tester,
    List<String> emojis, {
    bool reducedMotion = false,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reducedMotion),
          child: Scaffold(
            body: MessageBubble(
              message: message(),
              isMine: false,
              reactions: summary(emojis),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('a message with no reactions draws no row', (tester) async {
    await pump(tester, const []);

    expect(find.byType(ReactionBurst), findsNothing);
    expect(find.byType(ReactionBloom), findsNothing);
  });

  testWidgets('the first reaction bursts', (tester) async {
    await pump(tester, const []);
    await pump(tester, const ['👍']);
    await tester.pump();

    expect(
      tester.widget<ReactionBurst>(find.byType(ReactionBurst)).play,
      isTrue,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('a second reaction does not', (tester) async {
    await pump(tester, const ['👍']);
    await tester.pumpAndSettle();

    await pump(tester, const ['👍', '🔥']);
    await tester.pump();

    expect(
      tester.widget<ReactionBurst>(find.byType(ReactionBurst)).play,
      isFalse,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('a message that arrives already reacted to does not', (
    tester,
  ) async {
    // Scrolling past an old message is not a reaction happening.
    await pump(tester, const ['👍']);
    await tester.pump();

    expect(
      tester.widget<ReactionBurst>(find.byType(ReactionBurst)).play,
      isFalse,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('going back to none re-arms it', (tester) async {
    await pump(tester, const ['👍']);
    await tester.pumpAndSettle();

    await pump(tester, const []);
    await tester.pump();

    await pump(tester, const ['🔥']);
    await tester.pump();

    expect(
      tester.widget<ReactionBurst>(find.byType(ReactionBurst)).play,
      isTrue,
    );

    await tester.pumpAndSettle();
  });

  testWidgets('every chip blooms in, one per emoji', (tester) async {
    await pump(tester, const ['👍', '🔥']);
    await tester.pumpAndSettle();

    expect(find.byType(ReactionBloom), findsNWidgets(2));
  });

  testWidgets('reduced motion settles without animating', (tester) async {
    await pump(tester, const [], reducedMotion: true);
    await pump(tester, const ['👍'], reducedMotion: true);

    // Nothing left running: no controller was started, so a single pump is
    // enough to reach the final frame.
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('👍'), findsOneWidget);
  });
}
