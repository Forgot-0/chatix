import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/presentation/widgets/unread_divider.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  Future<void> pumpDivider(WidgetTester tester, {int? count}) =>
      tester.pumpWidgetBuilder(
        UnreadDivider(label: 'Unread messages', count: count),
        wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
      );

  testWidgets('rules the message list on both sides of the label', (
    tester,
  ) async {
    await pumpDivider(tester);

    expect(find.text('Unread messages'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('an unknown count draws no badge', (tester) async {
    await pumpDivider(tester);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a count of zero is treated as unknown, not as a zero badge', (
    tester,
  ) async {
    await pumpDivider(tester, count: 0);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a known count rides next to the label', (tester) async {
    await pumpDivider(tester, count: 12);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('a huge backlog is capped so the badge keeps its shape', (
    tester,
  ) async {
    await pumpDivider(tester, count: 4096);
    expect(find.text('99+'), findsOneWidget);
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('unread dividers on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'unread_divider_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(360, 160),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              UnreadDivider(label: 'Unread messages'),
              UnreadDivider(label: 'Unread messages', count: 7),
              UnreadDivider(label: 'Unread messages', count: 1240),
            ],
          ),
        );
      });
    }
  });
}
