import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_send_button.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One control doing three jobs. Which one it is doing has to be readable at
/// a glance, and slow mode has to hold it rather than let a message go out
/// and come back 429 (api-docs §5.2).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ComposerAction action,
    bool enabled = true,
    SlowMode slowMode = SlowMode.off,
    VoidCallback? onSend,
    void Function(VoiceRecording)? onVoiceRecorded,
    bool settle = true,
    DateTime Function()? clock,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ComposerSendButton(
                action: action,
                enabled: enabled,
                slowMode: slowMode,
                onSend: onSend,
                onVoiceRecorded: onVoiceRecorded ?? (_) {},
                clock: clock ?? ComposerSendButton.systemClock,
              ),
            ),
          ),
        ),
      ),
    );

    // A running countdown rebuilds once a second forever, and pumpAndSettle
    // would sit through the whole wait before returning.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Which icons are drawn at all, and how strongly. Mid-morph two of them
  /// are on screen at once, which is the point.
  Map<IconData, double> iconsOn(WidgetTester tester) {
    final result = <IconData, double>{};

    for (final element in find.byType(Icon).evaluate()) {
      final icon = element.widget as Icon;
      final opacity = tester.widgetList<Opacity>(
        find.ancestor(of: find.byWidget(icon), matching: find.byType(Opacity)),
      );
      result[icon.icon!] = opacity.isEmpty ? 1 : opacity.first.opacity;
    }
    return result;
  }

  group('which shape it wears', () {
    testWidgets('nothing typed: the microphone', (tester) async {
      await pump(tester, action: ComposerAction.record, enabled: false);

      expect(iconsOn(tester)[Icons.mic_none_rounded], 1);
      expect(iconsOn(tester).containsKey(Icons.send_rounded), isFalse);
    });

    testWidgets('something typed: the plane', (tester) async {
      await pump(tester, action: ComposerAction.send);

      expect(iconsOn(tester)[Icons.send_rounded], 1);
      expect(iconsOn(tester).containsKey(Icons.mic_none_rounded), isFalse);
    });

    testWidgets('editing: the tick', (tester) async {
      await pump(tester, action: ComposerAction.save);

      expect(iconsOn(tester)[Icons.check_rounded], 1);
    });
  });

  testWidgets('changing job morphs rather than swapping', (tester) async {
    await pump(tester, action: ComposerAction.record, enabled: false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ComposerSendButton(
                action: ComposerAction.send,
                enabled: true,
                slowMode: SlowMode.off,
                onSend: () {},
                onVoiceRecorded: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    // Halfway through, both icons are on screen and neither is at full
    // strength — a swap would show exactly one of them on every frame.
    await tester.pump(const Duration(milliseconds: 110));
    final midway = iconsOn(tester);

    expect(midway[Icons.mic_none_rounded], isNotNull);
    expect(midway[Icons.send_rounded], isNotNull);
    expect(midway[Icons.mic_none_rounded], lessThan(1));
    expect(midway[Icons.send_rounded], lessThan(1));

    await tester.pumpAndSettle();
    expect(iconsOn(tester)[Icons.send_rounded], 1);
  });

  group('sending', () {
    testWidgets('a tap sends when there is something to send', (tester) async {
      var sent = 0;
      await pump(tester, action: ComposerAction.send, onSend: () => sent++);

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pump();

      expect(sent, 1);
    });

    testWidgets('a disabled button does nothing', (tester) async {
      var sent = 0;
      await pump(
        tester,
        action: ComposerAction.send,
        enabled: false,
        onSend: () => sent++,
      );

      await tester.tap(find.byType(ComposerSendButton), warnIfMissed: false);
      await tester.pump();

      expect(sent, 0);
    });
  });

  group('slow mode', () {
    SlowMode waiting(int seconds) => SlowMode(
      interval: Duration(seconds: seconds),
      sendAllowedAt: DateTime.now().add(Duration(seconds: seconds)),
    );

    testWidgets('counts down in place of the icon', (tester) async {
      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: waiting(9),
        settle: false,
      );

      expect(find.text('9'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('a long wait is shown as minutes and seconds', (tester) async {
      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: waiting(90),
        settle: false,
      );

      expect(find.text('1:30'), findsOneWidget);
    });

    testWidgets('the number ticks down on its own', (tester) async {
      // The button reads the wall clock, which a test cannot move; this is
      // the same clock, moved by hand.
      var now = DateTime.utc(2026, 3, 1, 12);

      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: SlowMode(
          interval: const Duration(seconds: 5),
          sendAllowedAt: now.add(const Duration(seconds: 5)),
        ),
        clock: () => now,
        settle: false,
      );

      expect(find.text('5'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('nothing goes out while it runs', (tester) async {
      var sent = 0;
      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: waiting(9),
        onSend: () => sent++,
        settle: false,
      );

      await tester.tap(find.byType(ComposerSendButton), warnIfMissed: false);
      await tester.pump();

      expect(sent, 0);
    });

    testWidgets('and the button comes back once the wait is over', (
      tester,
    ) async {
      var sent = 0;
      var now = DateTime.utc(2026, 3, 1, 12);

      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: SlowMode(
          interval: const Duration(seconds: 1),
          sendAllowedAt: now.add(const Duration(seconds: 1)),
        ),
        clock: () => now,
        onSend: () => sent++,
        settle: false,
      );

      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pump();

      expect(sent, 1);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });
}
