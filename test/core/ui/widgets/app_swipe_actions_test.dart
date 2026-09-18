import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/haptics.dart';
import 'package:chatix/core/ui/widgets/app_swipe_actions.dart';

class _RecordingDriver implements HapticDriver {
  final List<HapticStrength> fired = <HapticStrength>[];

  @override
  void impact(HapticStrength strength) => fired.add(strength);
}

void main() {
  late List<String> pressed;
  late int rowTaps;
  late _RecordingDriver haptics;

  setUp(() {
    pressed = <String>[];
    rowTaps = 0;
    haptics = _RecordingDriver();
    AppHaptics.reset();
    AppHaptics.driver = haptics;
  });

  tearDown(AppHaptics.reset);

  SwipeAction action(String label) => SwipeAction(
    icon: Icons.check,
    label: label,
    background: const Color(0xFF112233),
    foreground: const Color(0xFFFFFFFF),
    onPressed: () => pressed.add(label),
  );

  Future<void> pumpRow(
    WidgetTester tester, {
    List<SwipeAction> leading = const [],
    List<SwipeAction> trailing = const [],
    bool enabled = true,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 400,
              child: AppSwipeActions(
                enabled: enabled,
                leading: leading,
                trailing: trailing,
                child: InkWell(
                  onTap: () => rowTaps++,
                  child: const SizedBox(
                    height: 72,
                    width: 400,
                    child: Center(child: Text('row')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the buttons are out of sight until the row is dragged', (
    tester,
  ) async {
    await pumpRow(tester, trailing: [action('Archive')]);

    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('dragging towards the end reveals the trailing actions', (
    tester,
  ) async {
    await pumpRow(tester, trailing: [action('Read'), action('Archive')]);

    await tester.drag(find.text('row'), const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
  });

  testWidgets('dragging the other way reveals the leading action', (
    tester,
  ) async {
    await pumpRow(
      tester,
      leading: [action('Mute')],
      trailing: [action('Archive')],
    );

    await tester.drag(find.text('row'), const Offset(120, 0));
    await tester.pumpAndSettle();

    expect(find.text('Mute'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('a short drag springs back and reveals nothing', (tester) async {
    await pumpRow(tester, trailing: [action('Archive')]);

    await tester.drag(find.text('row'), const Offset(-12, 0));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('tapping an action runs it and puts the row back', (
    tester,
  ) async {
    await pumpRow(tester, trailing: [action('Archive')]);

    await tester.drag(find.text('row'), const Offset(-160, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Archive'));
    await tester.pumpAndSettle();

    expect(pressed, ['Archive']);
    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('while the buttons are out, a tap on the row closes them', (
    tester,
  ) async {
    await pumpRow(tester, trailing: [action('Archive')]);

    await tester.drag(find.text('row'), const Offset(-160, 0));
    await tester.pumpAndSettle();

    // The tap is meant to land on the shield over the row, not on the row.
    await tester.tap(find.text('row'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(rowTaps, 0);
    expect(find.text('Archive'), findsNothing);

    // And the row is live again once they are away.
    await tester.tap(find.text('row'));
    await tester.pumpAndSettle();
    expect(rowTaps, 1);
  });

  testWidgets('disabled, the row is just the row', (tester) async {
    await pumpRow(tester, trailing: [action('Archive')], enabled: false);

    await tester.drag(find.text('row'), const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(find.text('Archive'), findsNothing);
  });

  testWidgets('the drag ticks once as it passes the point of no return', (
    tester,
  ) async {
    await pumpRow(tester, trailing: [action('Archive')]);

    final row = find.text('row');
    final start = tester.getCenter(row);
    final gesture = await tester.startGesture(start);

    // Short of halfway: nothing has changed meaning yet.
    await gesture.moveBy(const Offset(-20, 0));
    await tester.pump();
    expect(haptics.fired, isEmpty);

    // Past it, in several steps — one crossing, one tick.
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(-20, 0));
      await tester.pump();
    }
    expect(haptics.fired, [HapticStrength.selection]);

    // Wobbling back and forth over the line does not turn it into a buzz.
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();
    expect(haptics.fired, hasLength(2));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('with haptics switched off the gesture is silent', (
    tester,
  ) async {
    AppHaptics.setEnabled(false);
    await pumpRow(tester, trailing: [action('Archive')]);

    await tester.drag(find.text('row'), const Offset(-160, 0));
    await tester.pumpAndSettle();

    expect(haptics.fired, isEmpty);
    // And the gesture itself still worked.
    expect(find.text('Archive'), findsOneWidget);
  });
}
