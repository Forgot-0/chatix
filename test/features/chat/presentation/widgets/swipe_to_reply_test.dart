import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/presentation/widgets/swipe_to_reply.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  Widget target() => Container(
    key: const ValueKey('bubble'),
    width: 200,
    height: 48,
    color: const Color(0xFF6E56F8),
  );

  Future<int> swipe(
    WidgetTester tester, {
    required double by,
    bool enabled = true,
    VoidCallback? onReply,
  }) async {
    var replies = 0;

    await tester.pumpWidgetBuilder(
      SwipeToReply(
        enabled: enabled,
        onReply: onReply ?? () => replies++,
        child: target(),
      ),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    await tester.drag(find.byKey(const ValueKey('bubble')), Offset(by, 0));
    await tester.pumpAndSettle();

    return replies;
  }

  testWidgets('a drag past the threshold replies', (tester) async {
    expect(await swipe(tester, by: 60), 1);
  });

  testWidgets('a short drag does not', (tester) async {
    expect(await swipe(tester, by: 20), 0);
  });

  testWidgets('a leftward drag never fires', (tester) async {
    expect(await swipe(tester, by: -80), 0);
  });

  testWidgets('the message springs back to where it started', (tester) async {
    await tester.pumpWidgetBuilder(
      SwipeToReply(onReply: () {}, child: target()),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    final rest = tester.getTopLeft(find.byKey(const ValueKey('bubble')));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('bubble'))),
    );
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump();

    expect(
      tester.getTopLeft(find.byKey(const ValueKey('bubble'))).dx,
      greaterThan(rest.dx),
    );

    await gesture.up();
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(const ValueKey('bubble'))), rest);
  });

  testWidgets('rubber-banding keeps the travel under the ceiling', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      SwipeToReply(onReply: () {}, child: target()),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    final rest = tester.getTopLeft(find.byKey(const ValueKey('bubble'))).dx;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('bubble'))),
    );
    await gesture.moveBy(const Offset(400, 0));
    await tester.pump();

    final travelled =
        tester.getTopLeft(find.byKey(const ValueKey('bubble'))).dx - rest;
    expect(travelled, lessThanOrEqualTo(72));
    expect(travelled, greaterThan(44));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a message with nothing to reply to does not move', (
    tester,
  ) async {
    await tester.pumpWidgetBuilder(
      SwipeToReply(child: target()),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    final rest = tester.getTopLeft(find.byKey(const ValueKey('bubble')));
    await tester.drag(find.byKey(const ValueKey('bubble')), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byKey(const ValueKey('bubble'))), rest);
    expect(find.byIcon(Icons.reply), findsNothing);
  });

  testWidgets('disabled while the list is in selection mode', (tester) async {
    expect(await swipe(tester, by: 80, enabled: false), 0);
  });

  testWidgets('one haptic when the gesture arms, not one per frame', (
    tester,
  ) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add('${call.arguments}');
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidgetBuilder(
      SwipeToReply(onReply: () {}, child: target()),
      wrapper: materialAppWrapper(theme: chatGoldenTheme(dark: false)),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('bubble'))),
    );

    // Well short of the threshold: nothing yet.
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    expect(haptics, isEmpty);

    // Across it, then further — the buzz belongs to the crossing, not to the
    // distance travelled after it.
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(haptics, hasLength(1));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('mid-swipe on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'swipe_to_reply_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(320, 100),
          // Held at the armed position: the icon is at full strength and the
          // bubble is as far right as the rubber band lets it go.
          interact: (tester) async {
            final gesture = await tester.startGesture(
              tester.getCenter(find.byKey(const ValueKey('bubble'))),
            );
            await gesture.moveBy(const Offset(90, 0));
            await tester.pump();
            addTearDown(() async => gesture.cancel());
          },
          pump: (tester) => tester.pump(const Duration(milliseconds: 16)),
          child: SwipeToReply(onReply: () {}, child: target()),
        );
      });
    }
  });
}
