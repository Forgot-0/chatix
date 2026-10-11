import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_quick_actions.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    List<AppQuickAction> actions, {
    double width = 600,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: AppQuickActionsRow(actions: actions),
            ),
          ),
        ),
      ),
    );
  }

  AppQuickAction action(String label, {VoidCallback? onPressed}) =>
      AppQuickAction(icon: Icons.star, label: label, onPressed: onPressed);

  testWidgets('a tap runs the action', (tester) async {
    var taps = 0;
    await pump(tester, [action('Write', onPressed: () => taps++)]);

    await tester.tap(find.text('Write'));
    expect(taps, 1);
  });

  testWidgets('a button without an action is greyed, not hidden', (
    tester,
  ) async {
    await pump(tester, [action('Mute'), action('More', onPressed: () {})]);

    expect(find.text('Mute'), findsOneWidget);
    final scheme = AppTheme.light().colorScheme;
    final glyphs = tester.widgetList<Icon>(find.byIcon(Icons.star)).toList();
    expect(glyphs.first.color, isNot(scheme.primary));
    expect(glyphs.last.color, scheme.primary);
  });

  testWidgets('every action gets a slot of the same width, centred', (
    tester,
  ) async {
    await pump(tester, [
      action('A', onPressed: () {}),
      action('A much longer label', onPressed: () {}),
    ]);

    final first = tester.getCenter(find.text('A'));
    final second = tester.getCenter(find.text('A much longer label'));
    expect(second.dx - first.dx, QuickActionSizes.slot);
    // Centred on the 600 px row, which sits in the middle of an 800 px
    // test window.
    expect((first.dx + second.dx) / 2, moreOrLessEquals(400, epsilon: 0.5));
  });

  testWidgets('a pane too narrow for the slots shares out what it has', (
    tester,
  ) async {
    await pump(tester, [
      for (final label in ['One', 'Two', 'Three', 'Four'])
        action(label, onPressed: () {}),
    ], width: 280);

    expect(tester.takeException(), isNull);
    final first = tester.getCenter(find.text('One'));
    final last = tester.getCenter(find.text('Four'));
    expect(last.dx - first.dx, lessThan(QuickActionSizes.slot * 3));
  });

  testWidgets('the anchor key lands on the button', (tester) async {
    final key = GlobalKey();
    await pump(tester, [
      AppQuickAction(
        icon: Icons.more_horiz,
        label: 'More',
        onPressed: () {},
        anchorKey: key,
      ),
    ]);

    expect(key.currentContext, isNotNull);
    final box = key.currentContext!.findRenderObject()! as RenderBox;
    expect(box.size.width, QuickActionSizes.slot);
  });
}
