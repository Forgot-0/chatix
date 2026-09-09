import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/presentation/widgets/reaction_chip.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  Future<void> pumpChip(
    WidgetTester tester, {
    int count = 3,
    bool selected = false,
    List<int> recentUserIds = const [],
    VoidCallback? onTap,
    VoidCallback? onLongPress,
  }) => tester.pumpWidgetBuilder(
    ReactionChip(
      emoji: '+',
      count: count,
      selected: selected,
      recentUserIds: recentUserIds,
      onTap: onTap,
      onLongPress: onLongPress,
    ),
    wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
  );

  testWidgets('shows the emoji and the count', (tester) async {
    await pumpChip(tester, count: 12);

    expect(find.text('+'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('draws at most three faces, however many reacted', (
    tester,
  ) async {
    await pumpChip(
      tester,
      count: 40,
      recentUserIds: const [1, 2, 3, 4, 5],
    );

    // `recent_user_ids` is capped at 3 by the API too (ReactionLimits), but
    // the chip does not trust that.
    expect(
      find.descendant(
        of: find.byType(ReactionChip),
        matching: find.byType(Container),
      ),
      findsNWidgets(1 + ReactionChip.maxFaces),
    );
  });

  testWidgets('no faces when the group carries no recent ids', (tester) async {
    await pumpChip(tester);

    expect(
      find.descendant(
        of: find.byType(ReactionChip),
        matching: find.byType(Container),
      ),
      findsOneWidget,
    );
  });

  testWidgets('tap and long-press reach the caller', (tester) async {
    var taps = 0;
    var holds = 0;

    await pumpChip(
      tester,
      onTap: () => taps++,
      onLongPress: () => holds++,
    );

    await tester.tap(find.byType(ReactionChip));
    await tester.longPress(find.byType(ReactionChip));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(holds, 1);
  });

  testWidgets('a changed count crossfades only the digits', (tester) async {
    await pumpChip(tester, count: 3);
    expect(find.text('3'), findsOneWidget);

    await pumpChip(tester, count: 4);
    await tester.pump(const Duration(milliseconds: 60));

    // Mid-transition both digits are on screen — and nothing else has been
    // rebuilt from scratch, so the chip does not jump.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('announces itself as a selected button', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpChip(tester, selected: true, count: 2, onTap: () {});

    expect(
      tester.getSemantics(find.byType(ReactionChip)),
      isSemantics(
        label: '+ 2',
        isButton: true,
        isSelected: true,
        // The label replaces the raw glyphs, but the ink well's tap action
        // has to survive it — a chip that reads but cannot be activated is
        // worse than an unlabelled one.
        hasTapAction: true,
      ),
    );

    handle.dispose();
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('reaction chips on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'reaction_chip_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(360, 180),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  ReactionChip(emoji: '+', count: 1),
                  ReactionChip(emoji: '*', count: 12, selected: true),
                  ReactionChip(emoji: '=', count: 128),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 8,
                children: [
                  ReactionChip(
                    emoji: '+',
                    count: 3,
                    recentUserIds: [1, 2, 3],
                  ),
                  ReactionChip(
                    emoji: '*',
                    count: 9,
                    selected: true,
                    recentUserIds: [4, 5, 6],
                  ),
                ],
              ),
              // On the outgoing gradient, where the fills go translucent.
              _OnGradient(),
            ],
          ),
        );
      });
    }
  });
}

class _OnGradient extends StatelessWidget {
  const _OnGradient();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6E56F8), Color(0xFF4B36C9)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 8,
        children: [
          ReactionChip(emoji: '+', count: 2, onSurface: true),
          ReactionChip(
            emoji: '*',
            count: 5,
            selected: true,
            onSurface: true,
            recentUserIds: [7, 8],
          ),
        ],
      ),
    );
  }
}
