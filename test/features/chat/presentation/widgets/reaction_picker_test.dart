import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';

/// The full-catalog sheet. Everything it offers has to be something the
/// server would accept — the curated list (§5.7.2), narrowed by the chat's
/// own settings (§5.7.5), minus whatever the caps in §5.7.4 already rule out.
void main() {
  const messageId = 'm1';

  MessageReactionsEntity withMine(List<String> emojis) =>
      MessageReactionsEntity(
        messageId: messageId,
        groups: [
          for (final emoji in emojis)
            ReactionGroupEntity(emoji: emoji, count: 1, reactedByMe: true),
        ],
      );

  MessageReactionsEntity withOthers(List<String> emojis) =>
      MessageReactionsEntity(
        messageId: messageId,
        groups: [
          for (final emoji in emojis)
            ReactionGroupEntity(emoji: emoji, count: 2),
        ],
      );

  Future<void> pump(
    WidgetTester tester, {
    required MessageReactionsEntity reactions,
    required ChatReactionPolicy policy,
    required void Function(String) onSelected,
    List<String> recent = const [],
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReactionPicker(
            reactions: reactions,
            policy: policy,
            recent: recent,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  /// The emoji drawn right now, in order, however far the sheet is scrolled.
  List<String> renderedEmoji(WidgetTester tester) => tester
      .widgetList<ReactionEmojiButton>(find.byType(ReactionEmojiButton))
      .map((button) => button.emoji)
      .toList();

  testWidgets('offers the catalog when the chat allows any emoji', (
    tester,
  ) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: ChatReactionPolicy.unrestricted,
      onSelected: (_) {},
    );

    final rendered = renderedEmoji(tester).toSet();

    // Not every one of the 73 is built at once — the sheet scrolls — but
    // nothing outside the catalog may be drawn at any point.
    expect(rendered, isNotEmpty);
    for (final emoji in rendered) {
      expect(ReactionCatalog.isKnown(emoji), isTrue, reason: emoji);
    }
    expect(rendered, contains(ReactionCatalog.faces.first));
  });

  testWidgets('tapping an emoji reports it to the caller', (tester) async {
    final tapped = <String>[];
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: ChatReactionPolicy.unrestricted,
      onSelected: tapped.add,
    );

    final first = ReactionCatalog.faces.first;
    await tester.tap(find.text(first).first);
    await tester.pump();

    expect(tapped, [first]);
  });

  testWidgets('recents lead the sheet', (tester) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: ChatReactionPolicy.unrestricted,
      recent: const ['🎉', '🙏'],
      onSelected: (_) {},
    );

    expect(renderedEmoji(tester).take(2), ['🎉', '🙏']);
    expect(find.text('Recently used'), findsOneWidget);
  });

  testWidgets('a recent the chat no longer allows is dropped', (tester) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: const ChatReactionPolicy(enabled: true, whitelist: ['👍']),
      recent: const ['🎉', '👍'],
      onSelected: (_) {},
    );

    // '🎉' is in the catalog but not in this chat's white list, so it would
    // come back REACTION_NOT_ALLOWED.
    expect(renderedEmoji(tester), ['👍', '👍']);
  });

  testWidgets('reactions_mode "some" narrows the sheet to the white list', (
    tester,
  ) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: const ChatReactionPolicy(enabled: true, whitelist: ['👍', '🔥']),
      onSelected: (_) {},
    );

    expect(renderedEmoji(tester), ['👍', '🔥']);
  });

  testWidgets('reactions_mode "none" explains instead of showing emoji', (
    tester,
  ) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: const ChatReactionPolicy(enabled: false),
      onSelected: (_) {},
    );

    expect(find.byType(ReactionEmojiButton), findsNothing);
    expect(find.text('Reactions are off in this chat'), findsOneWidget);
  });

  testWidgets('a white list the catalog does not cover leaves nothing', (
    tester,
  ) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: const ChatReactionPolicy(enabled: true, whitelist: ['🫠']),
      onSelected: (_) {},
    );

    expect(find.byType(ReactionEmojiButton), findsNothing);
    expect(
      find.text('No reactions are available in this chat'),
      findsOneWidget,
    );
  });

  group('the caps from §5.7.4, before the tap rather than after the 400', () {
    testWidgets('at the per-user cap only my own emoji stay tappable', (
      tester,
    ) async {
      final mine = ReactionCatalog.faces.take(3).toList();
      final tapped = <String>[];

      await pump(
        tester,
        reactions: withMine(mine),
        policy: ChatReactionPolicy.unrestricted,
        onSelected: tapped.add,
      );

      // Taking one of mine back is the only way out of a full set.
      await tester.tap(find.text(mine.first).first);
      await tester.pump();
      expect(tapped, [mine.first]);

      // A fourth would be refused with TOO_MANY_REACTIONS.
      final blocked = ReactionCatalog.faces[3];
      await tester.tap(find.text(blocked).first, warnIfMissed: false);
      await tester.pump();
      expect(tapped, [mine.first]);
    });

    testWidgets('the per-user cap is named under the grid', (tester) async {
      await pump(
        tester,
        reactions: withMine(ReactionCatalog.faces.take(3).toList()),
        policy: ChatReactionPolicy.unrestricted,
        onSelected: (_) {},
      );

      expect(
        find.text('You can add up to 3 reactions per message'),
        findsOneWidget,
      );
    });

    testWidgets('below the cap every emoji is tappable', (tester) async {
      final tapped = <String>[];
      await pump(
        tester,
        reactions: withMine(ReactionCatalog.faces.take(2).toList()),
        policy: ChatReactionPolicy.unrestricted,
        onSelected: tapped.add,
      );

      final wanted = ReactionCatalog.faces[3];
      await tester.tap(find.text(wanted).first);
      await tester.pump();

      expect(tapped, [wanted]);
    });

    testWidgets('at 20 distinct emoji only the ones already there can be '
        'joined', (tester) async {
      final onMessage = ReactionCatalog.faces
          .take(ReactionLimits.maxDistinctPerMessage)
          .toList();
      final tapped = <String>[];

      await pump(
        tester,
        reactions: withOthers(onMessage),
        policy: ChatReactionPolicy.unrestricted,
        onSelected: tapped.add,
      );

      // Joining an existing group adds no new one, so it stays open...
      await tester.tap(find.text(onMessage.first).first);
      await tester.pump();
      expect(tapped, [onMessage.first]);

      // ...while a twenty-first emoji would be refused.
      final blocked =
          ReactionCatalog.faces[ReactionLimits.maxDistinctPerMessage];
      await tester.tap(find.text(blocked).first, warnIfMissed: false);
      await tester.pump();
      expect(tapped, [onMessage.first]);

      expect(
        find.text('This message already has 20 different reactions'),
        findsOneWidget,
      );
    });
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('the catalog sheet on the ${entry.key} theme', (
        tester,
      ) async {
        await pumpChatGolden(
          tester,
          name: 'reaction_catalog_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(360, 420),
          child: ReactionPicker(
            reactions: withMine(const ['👍']),
            policy: ChatReactionPolicy.unrestricted,
            recent: const ['🎉', '🙏', '👍'],
            onSelected: (_) {},
          ),
        );
      });
    }
  });
}
