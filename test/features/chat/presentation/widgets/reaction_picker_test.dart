import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/set_reaction_use_case.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

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

  Future<void> pump(
    WidgetTester tester, {
    required MessageReactionsEntity reactions,
    required ChatReactionPolicy policy,
    required void Function(String) onSelected,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ReactionPicker(
            reactions: reactions,
            policy: policy,
            onSelected: onSelected,
          ),
        ),
      ),
    );
  }

  testWidgets('offers the quick set when the chat allows any emoji', (
    tester,
  ) async {
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: ChatReactionPolicy.unrestricted,
      onSelected: (_) {},
    );

    for (final emoji in kQuickReactions) {
      expect(find.text(emoji), findsOneWidget, reason: emoji);
    }
  });

  testWidgets('tapping an emoji reports it to the caller', (tester) async {
    final tapped = <String>[];
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: ChatReactionPolicy.unrestricted,
      onSelected: tapped.add,
    );

    await tester.tap(find.text(kQuickReactions.first));
    await tester.pump();

    expect(tapped, [kQuickReactions.first]);
  });

  testWidgets('reactions_mode "some" narrows the row to the whitelist', (
    tester,
  ) async {
    const allowed = '👍';
    await pump(
      tester,
      reactions: MessageReactionsEntity.empty(messageId),
      policy: const ChatReactionPolicy(enabled: true, whitelist: [allowed]),
      onSelected: (_) {},
    );

    // Anything outside the whitelist would come back REACTION_NOT_ALLOWED,
    // so it must not be offered at all (api-docs §5.7.4).
    expect(find.text(allowed), findsOneWidget);
    for (final emoji in kQuickReactions.where((e) => e != allowed)) {
      expect(find.text(emoji), findsNothing, reason: emoji);
    }
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

    for (final emoji in kQuickReactions) {
      expect(find.text(emoji), findsNothing, reason: emoji);
    }
    expect(find.byType(Text), findsOneWidget);
  });

  testWidgets('at the per-user cap only my own emoji stay tappable', (
    tester,
  ) async {
    final mine = kQuickReactions.take(3).toList();
    final tapped = <String>[];

    await pump(
      tester,
      reactions: withMine(mine),
      policy: ChatReactionPolicy.unrestricted,
      onSelected: tapped.add,
    );

    // Removing one of mine is always allowed...
    await tester.tap(find.text(mine.first));
    await tester.pump();
    expect(tapped, [mine.first]);

    // ...but a fourth distinct emoji would be rejected with TOO_MANY_REACTIONS.
    final blocked = kQuickReactions[3];
    await tester.tap(find.text(blocked), warnIfMissed: false);
    await tester.pump();
    expect(tapped, [mine.first]);
  });

  testWidgets('below the cap every emoji is tappable', (tester) async {
    final tapped = <String>[];
    await pump(
      tester,
      reactions: withMine(kQuickReactions.take(2).toList()),
      policy: ChatReactionPolicy.unrestricted,
      onSelected: tapped.add,
    );

    await tester.tap(find.text(kQuickReactions[3]));
    await tester.pump();

    expect(tapped, [kQuickReactions[3]]);
  });
}
