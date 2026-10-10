import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_prefs_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';
import 'package:chatix/features/chat/presentation/providers/composer_keyboard_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_panel_host.dart';

/// The keyboard and the emoji panel trade places without the conversation
/// moving: the composer's bottom edge stays put through every frame of the
/// swap, whichever way it goes.
void main() {
  group('geometry', () {
    ComposerPanelGeometry frame({
      double consumed = 0,
      double local = 0,
      double panel = 300,
      bool showsPanel = true,
      bool searching = false,
    }) => ComposerPanelGeometry.resolve(
      consumed: consumed,
      localInset: local,
      panel: panel,
      showsPanel: showsPanel,
      searching: searching,
    );

    /// How high above the chat's own bottom edge the composer stands.
    double composerLift(ComposerPanelGeometry g, {double consumed = 0}) =>
        consumed + g.slot;

    test('with nothing open the box is just the keyboard over it', () {
      final g = frame(showsPanel: false, local: 280);

      expect(g.slot, 280);
      expect(g.panelHeight, 0);
    });

    test('keyboard going down under an open panel: the composer stays', () {
      // The keyboard was 300 and the panel opens at the same 300.
      for (final keyboard in <double>[300, 240, 150, 60, 0]) {
        final g = frame(local: keyboard);
        expect(composerLift(g), 300, reason: 'keyboard at $keyboard');
        expect(g.panelHeight, 300);
      }
    });

    test('the same when a scaffold above is the one shrinking', () {
      for (final keyboard in <double>[300, 240, 150, 60, 0]) {
        final g = frame(consumed: keyboard);
        expect(
          composerLift(g, consumed: keyboard),
          300,
          reason: 'keyboard at $keyboard',
        );
      }
    });

    test('a keyboard taller than the panel pushes the composer up', () {
      final g = frame(local: 340);

      expect(composerLift(g), 340);
    });

    test('searching puts the panel on top of the keyboard, as a strip', () {
      final g = frame(local: 300, searching: true);

      expect(g.compact, isTrue);
      expect(g.panelHeight, EmojiPanelSizes.searchStripHeight);
      expect(g.slot, 300 + EmojiPanelSizes.searchStripHeight);
    });

    test('searching with the keyboard gone is the whole panel again', () {
      final g = frame(searching: true);

      expect(g.compact, isFalse);
      expect(g.panelHeight, 300);
      expect(g.slot, 300);
    });
  });

  group('the controller', () {
    test('only a phone keeps the keyboard down for the panel', () {
      final phone = ComposerInputController(softKeyboard: true)..openEmoji();
      final desktop = ComposerInputController(softKeyboard: false)..openEmoji();

      expect(phone.holdsKeyboard, isTrue);
      expect(desktop.holdsKeyboard, isFalse);
      expect(desktop.showsPanel, isTrue);
    });

    test('back to the keyboard waits for it on a phone, not a desktop', () {
      final phone = ComposerInputController(softKeyboard: true)
        ..openEmoji()
        ..showKeyboard();
      final desktop = ComposerInputController(softKeyboard: false)
        ..openEmoji()
        ..showKeyboard();

      expect(phone.isAwaitingKeyboard, isTrue);
      expect(phone.showsPanel, isTrue);
      expect(desktop.showsPanel, isFalse);

      phone.keyboardArrived();
      expect(phone.showsPanel, isFalse);
    });

    test('closing forgets the search and any wait', () {
      final c = ComposerInputController(softKeyboard: true)
        ..openEmoji()
        ..setSearching(value: true)
        ..close();

      expect(c.isEmojiOpen, isFalse);
      expect(c.isSearching, isFalse);
      expect(c.showsPanel, isFalse);
    });

    test('search focus without the panel means nothing', () {
      final c = ComposerInputController(softKeyboard: true)
        ..setSearching(value: true);

      expect(c.isSearching, isFalse);
    });
  });

  group('on screen', () {
    const composerKey = Key('composer');
    const panelKey = Key('panel');
    const keyboard = 320.0;

    late InMemoryChatLocalPrefsStore prefs;
    late ComposerInputController input;

    setUp(() {
      prefs = InMemoryChatLocalPrefsStore();
      input = ComposerInputController(softKeyboard: true);
    });

    tearDown(() => input.dispose());

    void setKeyboard(WidgetTester tester, double height) {
      tester.view.viewInsets = FakeViewPadding(
        bottom: height * tester.view.devicePixelRatio,
      );
    }

    Future<ProviderContainer> pumpHost(
      WidgetTester tester, {
      bool outerScaffoldResizes = false,
    }) async {
      addTearDown(tester.view.resetViewInsets);

      final container = ProviderContainer(
        overrides: [chatLocalPrefsStoreProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final host = Scaffold(
        resizeToAvoidBottomInset: false,
        body: ComposerPanelHost(
          controller: input,
          panelBuilder: (context, height, compact) =>
              Container(key: panelKey, color: Colors.amber, height: height),
          child: const Column(
            children: [
              Expanded(child: ColoredBox(color: Colors.blue)),
              SizedBox(key: composerKey, height: 56),
            ],
          ),
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            // The shape of the app's shell: an outer scaffold with its own
            // keyboard avoidance, the chat inside it.
            home: outerScaffoldResizes ? Scaffold(body: host) : host,
          ),
        ),
      );
      return container;
    }

    double composerBottom(WidgetTester tester) =>
        tester.getBottomLeft(find.byKey(composerKey)).dy;

    for (final outer in [false, true]) {
      final label = outer ? 'inside a resizing scaffold' : 'on its own';

      testWidgets('keyboard to panel and back without a jump, $label', (
        tester,
      ) async {
        final container = await pumpHost(tester, outerScaffoldResizes: outer);
        final screen =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;

        // The keyboard comes up and settles; its height is remembered.
        setKeyboard(tester, keyboard);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(container.read(composerKeyboardHeightProvider), keyboard);

        final resting = composerBottom(tester);
        expect(resting, closeTo(screen - keyboard, 0.5));

        // Smiley: the panel opens at the keyboard's height, and the
        // keyboard goes down under it frame by frame.
        input.openEmoji();
        await tester.pump();
        for (final step in <double>[keyboard, 240, 160, 80, 0]) {
          setKeyboard(tester, step);
          await tester.pump();
          expect(
            composerBottom(tester),
            closeTo(resting, 0.5),
            reason: '$step',
          );
        }
        expect(tester.getSize(find.byKey(panelKey)).height, keyboard);

        // Back to typing: the keyboard comes up over the panel.
        input.showKeyboard();
        await tester.pump();
        for (final step in <double>[0, 100, 200, 300, keyboard]) {
          setKeyboard(tester, step);
          await tester.pump();
          expect(
            composerBottom(tester),
            closeTo(resting, 0.5),
            reason: '$step',
          );
        }

        // Once it is all the way up, the panel is gone.
        await tester.pump();
        expect(input.showsPanel, isFalse);
        expect(find.byKey(panelKey), findsNothing);
        expect(composerBottom(tester), closeTo(resting, 0.5));
      });
    }

    testWidgets('before any keyboard, the panel opens at a default height', (
      tester,
    ) async {
      await pumpHost(tester);

      input.openEmoji();
      await tester.pump();

      expect(
        tester.getSize(find.byKey(panelKey)).height,
        EmojiPanelSizes.defaultHeight,
      );
    });

    testWidgets('a keyboard that never comes does not hold the room forever', (
      tester,
    ) async {
      await pumpHost(tester);

      input.openEmoji();
      await tester.pump();
      input.showKeyboard();
      await tester.pump();
      expect(input.showsPanel, isTrue);

      await tester.pump(const Duration(seconds: 1));

      expect(input.showsPanel, isFalse);
    });

    testWidgets('an accessory bar is not remembered as a keyboard', (
      tester,
    ) async {
      final container = await pumpHost(tester);

      setKeyboard(tester, 44);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(container.read(composerKeyboardHeightProvider), isNull);
    });
  });
}
