import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/presentation/utils/message_actions.dart';
import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/message_forward_header.dart';
import 'package:chatix/features/chat/presentation/widgets/message_reply_quote.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_picker.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';

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
    String? content = 'hello',
    MessageType type = MessageType.text,
    bool isEdited = false,
    MessageEntity? replyTo,
    String? replyToId,
    MessageEntity? forwardedFrom,
    int? forwardedFromAuthorId,
    List<AttachmentEntity> attachments = const [],
    List<ReactionGroupEntity> reactions = const [],
  }) => MessageEntity(
    id: id,
    chatId: 'c',
    seq: seq,
    authorId: authorId,
    type: type,
    content: content,
    replyToId: replyToId ?? replyTo?.id,
    forwardedFromChatId: forwardedFrom == null && forwardedFromAuthorId == null
        ? null
        : 'other',
    forwardedFromMessageId: forwardedFrom?.id,
    forwardedFromAuthorId: forwardedFromAuthorId ?? forwardedFrom?.authorId,
    isEdited: isEdited,
    createdAt: DateTime(2026, 1, 1, 14, 30),
    attachments: attachments,
    replyTo: replyTo,
    forwardedFrom: forwardedFrom,
    profile: authorId == null ? null : profile(authorId, 'Ada'),
    reactions: reactions,
  );

  Future<void> pump(
    WidgetTester tester,
    Widget bubble, {
    bool dark = false,
    AppDensity? density,
    Size surfaceSize = const Size(400, 700),
  }) => tester.pumpWidgetBuilder(
    Align(alignment: Alignment.topCenter, child: bubble),
    wrapper: materialAppWrapper(
      theme: chatGoldenTheme(dark: dark, density: density),
      localizations: AppLocalizations.localizationsDelegates,
    ),
    surfaceSize: surfaceSize,
  );

  group('system messages', () {
    testWidgets('are a centred capsule, not a bubble', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: message(
            type: MessageType.system,
            authorId: null,
            content: 'Ada joined the chat',
          ),
          isMine: false,
        ),
      );

      expect(find.text('Ada joined the chat'), findsOneWidget);
      // No timestamp, no ticks, nothing to reply to.
      expect(find.text('2:30 PM'), findsNothing);
      expect(find.byType(StatusTicks), findsNothing);
    });
  });

  group('quoting and forwarding', () {
    testWidgets('a reply quotes the original with its author', (tester) async {
      final original = message(id: 'm0', seq: 0, content: 'the question');

      await pump(
        tester,
        MessageBubble(
          message: message(content: 'the answer', replyTo: original),
          isMine: false,
        ),
      );

      expect(find.byType(MessageReplyQuote), findsOneWidget);
      expect(find.text('the question'), findsOneWidget);
      expect(find.text('Ada'), findsWidgets);
    });

    testWidgets('a reply to something gone still says so', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: message(content: 'the answer', replyToId: 'gone'),
          isMine: false,
        ),
      );

      expect(find.byType(MessageReplyQuote), findsOneWidget);
      expect(find.text('That message is no longer available'), findsOneWidget);
    });

    testWidgets('tapping a quote goes to the original', (tester) async {
      var jumped = false;

      await pump(
        tester,
        MessageBubble(
          message: message(
            content: 'the answer',
            replyTo: message(id: 'm0', seq: 0, content: 'the question'),
          ),
          isMine: false,
          onJumpToOriginal: () => jumped = true,
        ),
      );

      await tester.tap(find.byType(MessageReplyQuote));
      // Past the double-tap window: the reaction gesture holds the arena open
      // until it is sure a second tap is not coming.
      await tester.pump(const Duration(milliseconds: 400));

      expect(jumped, isTrue);
    });

    testWidgets('a forward gets a header, not a quote', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: message(
            content: 'passing this on',
            forwardedFrom: message(id: 'm9', seq: 9, authorId: 43),
          ),
          isMine: false,
        ),
      );

      expect(find.byType(MessageForwardHeader), findsOneWidget);
      expect(find.byType(MessageReplyQuote), findsNothing);
    });

    testWidgets('a forward the server could not resolve still says so', (
      tester,
    ) async {
      await pump(
        tester,
        MessageBubble(
          message: message(content: 'x', forwardedFromAuthorId: 43),
          isMine: false,
        ),
      );

      expect(find.textContaining('Forwarded'), findsOneWidget);
    });
  });

  group('text', () {
    testWidgets('markup in content is drawn, never interpreted', (
      tester,
    ) async {
      const raw = '<b>not bold</b> & "quoted"';

      await pump(
        tester,
        MessageBubble(message: message(content: raw), isMine: false),
      );

      expect(find.text(raw), findsOneWidget);
    });

    testWidgets('a url is tappable and reports what was tapped', (
      tester,
    ) async {
      LinkSpan? opened;

      await pump(
        tester,
        MessageBubble(
          message: message(content: 'go to https://example.com now'),
          isMine: false,
          onOpenLink: (link) => opened = link,
        ),
      );

      final text = tester.widget<Text>(
        find.byWidgetPredicate((w) => w is Text && w.textSpan != null),
      );
      final span = text.textSpan! as TextSpan;
      final link = span.children!.whereType<TextSpan>().firstWhere(
        (s) => s.recognizer != null,
      );

      expect(link.text, 'https://example.com');

      (link.recognizer! as dynamic).onTap();
      expect(opened?.kind, MessageLinkKind.url);
      expect(opened?.target, 'https://example.com');
    });
  });

  group('gestures', () {
    testWidgets('a double tap sends the first quick reaction', (tester) async {
      final sent = <String>[];

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          quickReactions: const ['🔥', '👍'],
          onToggleReaction: sent.add,
        ),
      );

      await tester.tap(find.text('hello'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('hello'));
      await tester.pumpAndSettle();

      expect(sent, ['🔥']);
    });

    testWidgets('a double tap with nothing allowed does nothing', (
      tester,
    ) async {
      var reacted = false;

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          onToggleReaction: (_) => reacted = true,
        ),
      );

      await tester.tap(find.text('hello'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('hello'));
      await tester.pumpAndSettle();

      expect(reacted, isFalse);
    });

    testWidgets('tapping the time opens the details', (tester) async {
      var opened = false;

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          onShowDetails: () => opened = true,
        ),
      );

      await tester.tap(find.text('2:30 PM'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(opened, isTrue);
    });

    testWidgets('swiping right replies', (tester) async {
      var replied = false;

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          onReply: () => replied = true,
        ),
      );

      await tester.drag(find.text('hello'), const Offset(80, 0));
      await tester.pumpAndSettle();

      expect(replied, isTrue);
    });
  });

  group('the context menu', () {
    testWidgets('a long press lifts the message over a blurred chat', (
      tester,
    ) async {
      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.reply, MessageAction.copy],
          quickReactions: const ['🔥'],
          onToggleReaction: (_) {},
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();

      expect(find.byType(BackdropFilter), findsWidgets);
      // The message itself is on screen twice now: in the list and lifted
      // over it.
      expect(find.text('hello'), findsNWidgets(2));
      expect(find.text('Reply'), findsOneWidget);
      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('🔥'), findsOneWidget);
    });

    testWidgets('only the actions it was given appear', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.copy, MessageAction.details],
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();

      expect(find.text('Copy text'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('picking an action runs it and closes the menu', (
      tester,
    ) async {
      var replied = false;

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.reply],
          onReply: () => replied = true,
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reply'));
      await tester.pumpAndSettle();

      expect(replied, isTrue);
      expect(find.text('Reply'), findsNothing);
    });

    testWidgets('picking a quick reaction sends it', (tester) async {
      final sent = <String>[];

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.reply],
          quickReactions: const ['🔥', '👍'],
          onToggleReaction: sent.add,
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('👍'));
      await tester.pumpAndSettle();

      expect(sent, ['👍']);
    });

    testWidgets('the bar ends in a way into the full catalog', (tester) async {
      var opened = false;

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.reply],
          quickReactions: const ['🔥'],
          onToggleReaction: (_) {},
          onShowReactionPicker: () => opened = true,
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(opened, isTrue);
    });

    testWidgets('without a catalog to open, the bar has no more button', (
      tester,
    ) async {
      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.reply],
          quickReactions: const ['🔥'],
          onToggleReaction: (_) {},
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
    });

    testWidgets('at the per-user cap the bar stops taking new emoji', (
      tester,
    ) async {
      final sent = <String>[];

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          actions: const [MessageAction.reply],
          quickReactions: const ['🔥', '👍', '❤️', '😁'],
          // Three of ours already: a fourth would be TOO_MANY_REACTIONS
          // (api-docs §5.7.4), so it is refused here rather than there.
          reactions: const MessageReactionsEntity(
            messageId: 'm1',
            groups: [
              ReactionGroupEntity(emoji: '🔥', count: 1, reactedByMe: true),
              ReactionGroupEntity(emoji: '👍', count: 1, reactedByMe: true),
              ReactionGroupEntity(emoji: '❤️', count: 1, reactedByMe: true),
            ],
          ),
          onToggleReaction: sent.add,
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();

      // The bar's own buttons, not the chips under the message, which carry
      // the same emoji.
      Finder inBar(String emoji) => find.byWidgetPredicate(
        (widget) => widget is ReactionEmojiButton && widget.emoji == emoji,
      );

      await tester.tap(inBar('😁'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);

      // A refused tap is swallowed rather than closing the menu behind it.
      expect(find.text('Reply'), findsOneWidget);

      // Taking one back is still the way out.
      await tester.tap(inBar('🔥'));
      await tester.pumpAndSettle();
      expect(sent, ['🔥']);
    });

    testWidgets('no menu opens while selecting', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          selectionMode: true,
          actions: const [MessageAction.reply],
        ),
      );

      await tester.longPress(find.text('hello'));
      await tester.pumpAndSettle();

      expect(find.text('Reply'), findsNothing);
    });
  });

  group('selection mode', () {
    testWidgets('puts a checkbox beside every message', (tester) async {
      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          selectionMode: true,
          isSelected: true,
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('tapping anywhere on the row toggles it', (tester) async {
      var toggled = 0;

      await pump(
        tester,
        MessageBubble(
          message: message(),
          isMine: false,
          selectionMode: true,
          onSelectionToggled: () => toggled++,
        ),
      );

      await tester.tap(find.text('hello'));
      await tester.pumpAndSettle();

      expect(toggled, 1);
    });
  });

  group('what a screen reader hears', () {
    /// Everything spoken under [finder], in the order the reader meets it.
    ///
    /// A node that merges its descendants joins their labels with newlines,
    /// so those are split back out: what matters is the order the words are
    /// spoken in, not how many nodes they were spread across.
    List<String> spoken(WidgetTester tester, Finder finder) {
      final labels = <String>[];

      void walk(SemanticsNode node) {
        for (final line in node.label.split('\n')) {
          final trimmed = line.trim();
          if (trimmed.isNotEmpty) labels.add(trimmed);
        }
        node.visitChildren((child) {
          walk(child);
          return true;
        });
      }

      walk(tester.getSemantics(finder));
      return labels;
    }

    testWidgets('an incoming bubble names its author and its time', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(message: message(content: 'hello'), isMine: false),
      );

      expect(
        spoken(tester, find.byType(MessageBubble)),
        containsAllInOrder(<String>['Message from Ada, 2:30 PM', 'hello']),
      );

      handle.dispose();
    });

    testWidgets('your own bubble does not read your name back to you', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(message: message(content: 'hello'), isMine: true),
      );

      final labels = spoken(tester, find.byType(MessageBubble));
      expect(labels.first, 'Your message, 2:30 PM');
      expect(labels.join(' '), isNot(contains('Ada')));

      handle.dispose();
    });

    // The reading the brief asks for: who, when, what, and how many reacted.
    testWidgets('reactions are counted in words, after the text', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(
          message: message(content: 'hello'),
          isMine: false,
          reactions: MessageReactionsEntity(
            messageId: 'm1',
            groups: [
              const ReactionGroupEntity(
                emoji: '👍',
                count: 2,
                reactedByMe: false,
                recentUserIds: [1, 2],
              ),
            ],
          ),
          onToggleReaction: (_) {},
        ),
      );

      // The chips bloom in; until that settles they are transparent, and a
      // transparent subtree carries no semantics.
      await tester.pumpAndSettle();

      expect(
        spoken(tester, find.byType(MessageBubble)),
        containsAllInOrder(<String>[
          'Message from Ada, 2:30 PM',
          'hello',
          '👍, 2 reactions',
        ]),
      );

      handle.dispose();
    });

    testWidgets('the meta row says what the ticks mean', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(
          message: message(content: 'hello', isEdited: true),
          isMine: true,
          deliveryStatus: MessageDeliveryStatus.read,
          onShowDetails: () {},
        ),
      );

      expect(
        spoken(tester, find.byType(MessageBubble)),
        contains('edited, Read, Details'),
      );

      handle.dispose();
    });

    testWidgets('the clock is not read twice', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(message: message(content: 'hello'), isMine: false),
      );

      final clocks = spoken(
        tester,
        find.byType(MessageBubble),
      ).where((label) => label.contains('2:30 PM')).length;
      expect(clocks, 1);

      handle.dispose();
    });

    testWidgets('a system message says that is what it is', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(
          message: message(
            type: MessageType.system,
            authorId: null,
            content: 'Ada joined',
          ),
          isMine: false,
        ),
      );

      expect(
        spoken(tester, find.byType(MessageBubble)),
        containsAllInOrder(<String>['System message', 'Ada joined']),
      );

      handle.dispose();
    });

    testWidgets('the long-press menu is discoverable without sight', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        MessageBubble(
          message: message(content: 'hello'),
          isMine: false,
          actions: const [MessageAction.reply],
          onReply: () {},
        ),
      );

      // The action and its hint have to sit on the node that carries the
      // label, not on the row above it: a reader who focuses the bubble is
      // the one who needs to be told the menu is there.
      expect(
        tester.getSemantics(find.text('hello')),
        matchesSemantics(
          label: 'Message from Ada, 2:30 PM\nhello',
          hasLongPressAction: true,
          onLongPressHint: 'show message actions',
          textDirection: TextDirection.ltr,
        ),
      );

      handle.dispose();
    });
  });

  // Every shape a bubble takes, on both themes and at both densities —
  // sixteen frames that between them cover the padding, the corner, the
  // author line, the quote, the meta row and the chips.
  group('the whole bubble matrix', () {
    Widget everyKind() {
      final original = message(
        id: 'm0',
        seq: 0,
        authorId: 43,
        content: 'Where did we land on the cursor?',
      );

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MessageBubble(
            message: message(
              type: MessageType.system,
              authorId: null,
              content: 'Ada joined the chat',
            ),
            isMine: false,
          ),
          MessageBubble(
            message: message(content: 'Heading a run', seq: 2),
            isMine: false,
            showAuthor: true,
            isFirstInGroup: true,
            isLastInGroup: false,
            showMeta: false,
          ),
          MessageBubble(
            message: message(id: 'm3', seq: 3, content: 'Stacked under it'),
            isMine: false,
            isFirstInGroup: false,
            isLastInGroup: false,
            showMeta: false,
          ),
          MessageBubble(
            message: message(
              id: 'm4',
              seq: 4,
              content: 'Closing it, with a reply above',
              replyTo: original,
            ),
            isMine: false,
            isFirstInGroup: false,
            reactions: MessageReactionsEntity(
              messageId: 'm4',
              groups: const [
                ReactionGroupEntity(
                  emoji: '👍',
                  count: 2,
                  reactedByMe: true,
                  recentUserIds: [1, 2],
                ),
                ReactionGroupEntity(
                  emoji: '🎉',
                  count: 1,
                  reactedByMe: false,
                  recentUserIds: [3],
                ),
              ],
            ),
            onToggleReaction: (_) {},
          ),
          MessageBubble(
            message: message(
              id: 'm5',
              seq: 5,
              authorId: 7,
              content: 'Passing this on',
              isEdited: true,
              forwardedFrom: message(id: 'm9', seq: 9, authorId: 43),
            ),
            isMine: true,
            deliveryStatus: MessageDeliveryStatus.read,
          ),
          MessageBubble(
            message: message(
              id: 'm6',
              seq: 6,
              authorId: 7,
              content: 'Still going out',
            ),
            isMine: true,
            deliveryStatus: MessageDeliveryStatus.sending,
          ),
        ],
      );
    }

    for (final theme in chatGoldenThemes.entries) {
      for (final density in chatGoldenDensities.entries) {
        testGoldens('${theme.key} / ${density.key}', (tester) async {
          await pump(
            tester,
            everyKind(),
            dark: theme.value,
            density: density.value,
            surfaceSize: const Size(400, 620),
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'bubble_matrix_${theme.key}_${density.key}',
          );
        });
      }
    }
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('bubble states on the ${entry.key} theme', (tester) async {
        final original = message(
          id: 'm0',
          seq: 0,
          authorId: 43,
          content: 'Where did we land on the cursor?',
        );

        await pump(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MessageBubble(
                message: message(
                  type: MessageType.system,
                  authorId: null,
                  content: 'Ada joined the chat',
                ),
                isMine: false,
              ),
              MessageBubble(
                message: message(content: 'Two messages back', seq: 2),
                isMine: false,
                showAuthor: true,
              ),
              MessageBubble(
                message: message(
                  seq: 3,
                  content: 'Backward, see https://example.com',
                  replyTo: original,
                ),
                isMine: false,
                onOpenLink: (_) {},
              ),
              MessageBubble(
                message: message(
                  seq: 4,
                  authorId: 7,
                  content: 'Passing this on',
                  isEdited: true,
                  forwardedFrom: message(id: 'm9', seq: 9, authorId: 43),
                ),
                isMine: true,
                deliveryStatus: MessageDeliveryStatus.read,
              ),
            ],
          ),
          dark: entry.value,
          surfaceSize: const Size(400, 460),
        );

        await screenMatchesGolden(tester, 'message_bubble_${entry.key}');
      });

      testGoldens('the context menu on the ${entry.key} theme', (tester) async {
        await pump(
          tester,
          Padding(
            padding: const EdgeInsets.only(top: 120),
            child: MessageBubble(
              message: message(
                content: 'Shipping it after lunch then',
                seq: 12,
              ),
              isMine: false,
              showAuthor: true,
              actions: const [
                MessageAction.reply,
                MessageAction.react,
                MessageAction.copy,
                MessageAction.forward,
                MessageAction.select,
                MessageAction.delete,
                MessageAction.details,
              ],
              quickReactions: const ['🔥', '👍', '❤️', '😁'],
              onToggleReaction: (_) {},
              onShowReactionPicker: () {},
            ),
          ),
          dark: entry.value,
          surfaceSize: const Size(400, 700),
        );

        await tester.longPress(find.text('Shipping it after lunch then'));
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'message_actions_${entry.key}');
      });
    }
  });
}
