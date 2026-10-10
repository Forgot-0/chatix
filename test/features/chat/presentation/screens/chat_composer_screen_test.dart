import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/recent_emoji_provider.dart';
import 'package:chatix/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/emoji_panel.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/mention_suggestions.dart';

import '../../../../helpers/chat_screen_harness.dart';
import '../../../../helpers/pane_frame.dart';

/// The composer on the real chat screen: its states, the emoji panel that
/// takes the keyboard's place, and how each looks on a phone and in the
/// right pane of a desktop.
void main() {
  setUpAll(ChatScreenHarness.setUpAll);

  late ChatScreenHarness harness;

  setUp(() {
    harness = ChatScreenHarness()..setUp();
    // A blinking caret never lets a frame settle, and draws differently
    // from one golden run to the next.
    EditableText.debugDeterministicCursor = true;
  });

  tearDown(() async {
    EditableText.debugDeterministicCursor = false;
    await harness.tearDown();
  });

  Finder field() => find.descendant(
    of: find.byType(ChatComposer),
    matching: find.byType(EditableText),
  );

  String textOf(WidgetTester tester) =>
      tester.widget<EditableText>(field()).controller.text;

  Future<void> openEmoji(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Эмодзи'));
    await tester.pumpAndSettle();
  }

  group('the emoji panel', () {
    testWidgets('opens from the smiley, and an emoji goes in at the caret', (
      tester,
    ) async {
      final container = await harness.pump(tester);

      await tester.enterText(field(), 'Готово ');
      await tester.pump();
      await openEmoji(tester);

      expect(find.byType(EmojiPanel), findsOneWidget);
      // The button now offers the keyboard back.
      expect(find.byTooltip('Клавиатура'), findsOneWidget);

      await tester.tap(find.text('😀').first);
      await tester.pump();

      expect(textOf(tester), 'Готово 😀');
      expect(container.read(recentEmojiProvider).first, '😀');
    });

    testWidgets('its backspace takes a whole emoji off', (tester) async {
      await harness.pump(tester);

      await tester.enterText(field(), 'Ок 👍🏽');
      await tester.pump();
      await openEmoji(tester);

      await tester.tap(find.byTooltip('Стереть'));
      await tester.pump();

      expect(textOf(tester), 'Ок ');
    });

    testWidgets('leads with this device\'s recent emoji', (tester) async {
      await harness.prefs.writeRecentReactions(['🦄', '🔥']);
      await harness.pump(tester);

      await openEmoji(tester);

      expect(find.text('Недавние'), findsOneWidget);
      expect(find.text('🦄'), findsWidgets);
    });

    testWidgets('search answers in the reader\'s language', (tester) async {
      await harness.pump(tester);
      await openEmoji(tester);

      await tester.enterText(
        find.descendant(
          of: find.byType(EmojiPanel),
          matching: find.byType(EditableText),
        ),
        'пицца',
      );
      await tester.pumpAndSettle();

      expect(find.text('🍕'), findsOneWidget);
    });

    testWidgets('back puts the panel away before it leaves the chat', (
      tester,
    ) async {
      await harness.pump(tester);
      await openEmoji(tester);

      final handled = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.byType(EmojiPanel), findsNothing);
      expect(find.byType(ChatDetailScreen), findsOneWidget);
    });

    testWidgets('a tap on the field asks for the keyboard back', (
      tester,
    ) async {
      await harness.pump(tester);
      await openEmoji(tester);

      // While the panel is open the field keeps its caret but raises no
      // keyboard of its own.
      expect(tester.widget<EditableText>(field()).readOnly, isTrue);

      await tester.tap(field());
      await tester.pump();
      expect(tester.widget<EditableText>(field()).readOnly, isFalse);

      // No keyboard arrives in a test; the panel gives the room back after
      // waiting for one.
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(EmojiPanel), findsNothing);
    });

    testWidgets('a tap on the conversation puts it away', (tester) async {
      await harness.pump(tester);
      await openEmoji(tester);

      await tester.tapAt(const Offset(200, 160));
      await tester.pumpAndSettle();

      expect(find.byType(EmojiPanel), findsNothing);
    });
  });

  group('the draft', () {
    testWidgets('reaches the server once the typing stops, not per key', (
      tester,
    ) async {
      await harness.pump(tester);

      await tester.enterText(field(), 'з');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(field(), 'завтра');
      await tester.pump(const Duration(milliseconds: 1400));

      verifyNever(() => harness.updateState.setDraft(any(), any()));

      await tester.pump(const Duration(milliseconds: 200));

      verify(
        () => harness.updateState.setDraft(ChatScreenHarness.chatId, 'завтра'),
      ).called(1);
    });
  });

  group('mentions', () {
    Finder suggestion(String handle) => find.descendant(
      of: find.byType(MentionSuggestions),
      matching: find.textContaining(handle),
    );

    testWidgets('an @ offers the group, without the writer', (tester) async {
      await harness.pump(tester);

      await tester.enterText(field(), '@');
      await tester.pump();

      expect(find.byType(MentionSuggestions), findsOneWidget);
      expect(suggestion('@ada'), findsOneWidget);
      expect(suggestion('@linus'), findsOneWidget);
      expect(suggestion('@me'), findsNothing);
    });

    testWidgets('narrows by username and by name as the query grows', (
      tester,
    ) async {
      await harness.pump(tester);

      await tester.enterText(field(), 'спрошу @ad');
      await tester.pump();
      expect(suggestion('@ada'), findsOneWidget);
      expect(suggestion('@adele'), findsOneWidget);
      expect(suggestion('@grace'), findsNothing);

      await tester.enterText(field(), 'спрошу @Лин');
      await tester.pump();
      expect(suggestion('@linus'), findsOneWidget);
      expect(suggestion('@ada'), findsNothing);
    });

    testWidgets('picking one writes @username and a space', (tester) async {
      await harness.pump(tester);

      await tester.enterText(field(), 'спрошу @gr');
      await tester.pump();
      await tester.tap(suggestion('@grace'));
      await tester.pump();

      expect(textOf(tester), 'спрошу @grace ');
      expect(find.byType(MentionSuggestions), findsNothing);
    });

    testWidgets('arrows and Enter pick from the keyboard; Esc puts it away', (
      tester,
    ) async {
      await harness.pump(tester);

      await tester.enterText(field(), '@ad');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Ada first, Adele second.
      expect(textOf(tester), '@adele ');

      await tester.enterText(field(), '@ad');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(find.byType(MentionSuggestions), findsNothing);
      expect(textOf(tester), '@ad');
    });

    testWidgets('nothing to mention in a direct chat', (tester) async {
      await harness.tearDown();
      harness = ChatScreenHarness(
        type: ChatType.direct,
        people: const [ChatScreenHarness.myself, ChatScreenHarness.ada],
      )..setUp();
      await harness.pump(tester);

      await tester.enterText(field(), '@a');
      await tester.pump();

      expect(find.byType(MentionSuggestions), findsNothing);
    });
  });

  group('goldens', () {
    final states = <String, Future<void> Function(WidgetTester tester)>{
      'empty': (tester) async {},
      'text': (tester) async {
        await tester.enterText(
          field(),
          'Скину черновик через час — посмотри раздел про миграции 🙏',
        );
        await tester.pumpAndSettle();
      },
      'reply': (tester) => ChatScreenHarness.pickFromMenu(
        tester,
        'Заметки к релизу готовы?',
        'Ответить',
      ),
      'edit': (tester) => ChatScreenHarness.pickFromMenu(
        tester,
        'Отправлю до обеда',
        'Изменить',
      ),
      'emoji': (tester) async {
        await openEmoji(tester);
      },
      'mentions': (tester) async {
        await tester.enterText(field(), 'Спрошу у @a');
        await tester.pumpAndSettle();
      },
    };

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        for (final state in states.entries) {
          testGoldens('${state.key}, ${window.name}, ${theme.key}', (
            tester,
          ) async {
            await harness.prefs.writeRecentReactions([
              '👍',
              '🔥',
              '🎉',
              '😂',
              '❤️',
              '🙏',
            ]);
            await harness.pump(tester, window: window, dark: theme.value);

            await state.value(tester);

            await screenMatchesGolden(
              tester,
              'composer_${state.key}_${window.name}_${theme.key}',
            );
          });
        }
      }
    }
  });
}
