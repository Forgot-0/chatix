import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/presentation/widgets/typing_dots.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  Finder dots() => find.descendant(
    of: find.byType(TypingDots),
    matching: find.byType(Container),
  );

  testWidgets('draws three dots', (tester) async {
    await tester.pumpWidgetBuilder(
      const TypingDots(),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(dots(), findsNWidgets(TypingDots.dotCount));
  });

  testWidgets('keeps animating frame after frame', (tester) async {
    await tester.pumpWidgetBuilder(
      const TypingDots(),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<Container>(dots().first).decoration;

    await tester.pump(const Duration(milliseconds: 300));
    final later = tester.widget<Container>(dots().first).decoration;

    expect(later, isNot(first));
  });

  testWidgets('holds still when the platform asks for reduced motion', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: TypingDots(),
      ),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    await tester.pump(const Duration(milliseconds: 100));
    final first = tester.widget<Container>(dots().first).decoration;

    await tester.pump(const Duration(milliseconds: 400));
    final later = tester.widget<Container>(dots().first).decoration;

    expect(later, first);
    expect(dots(), findsNWidgets(TypingDots.dotCount));
  });

  testWidgets('the labelled indicator shows what it was handed, no more', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const TypingIndicator(label: 'Ada is typing…'),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Ada is typing…'), findsOneWidget);
    expect(find.byType(TypingDots), findsOneWidget);
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('typing indicator on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'typing_dots_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(320, 120),
          // An endless animation never settles: the golden is taken at a
          // fixed point on the loop instead.
          pump: (tester) => tester.pump(const Duration(milliseconds: 400)),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: [
              TypingDots(dotSize: 8, spacing: 5),
              TypingIndicator(label: 'Ada is typing…'),
            ],
          ),
        );
      });
    }
  });
}
