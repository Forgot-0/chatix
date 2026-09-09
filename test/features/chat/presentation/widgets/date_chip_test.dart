import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/presentation/widgets/date_chip.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  testWidgets('blurs the backdrop when it floats over messages', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const DateChip(label: 'Today'),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('skips the blur — and its saveLayer — when inline', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      const DateChip(label: 'Today', blurred: false),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('fades out and stops taking taps when hidden', (tester) async {
    await tester.pumpWidgetBuilder(
      const DateChip(label: 'Today', visible: false),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );
    await tester.pumpAndSettle();

    // MaterialApp puts its own IgnorePointer/AnimatedOpacity in the tree, so
    // both finders are scoped to the chip.
    Finder inChip(Type type) => find.descendant(
      of: find.byType(DateChip),
      matching: find.byWidgetPredicate((w) => w.runtimeType == type),
    );

    expect(
      tester.widget<AnimatedOpacity>(inChip(AnimatedOpacity)).opacity,
      0,
    );
    expect(
      tester.widget<IgnorePointer>(inChip(IgnorePointer)).ignoring,
      isTrue,
    );
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('date chips on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'date_chip_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(320, 160),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Over content, where the blur has something to work on.
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 240,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6E56F8), Color(0xFF22C7A9)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const DateChip(label: 'Today'),
                ],
              ),
              const SizedBox(height: 20),
              const DateChip(label: '12 May', blurred: false),
            ],
          ),
        );
      });
    }
  });
}
