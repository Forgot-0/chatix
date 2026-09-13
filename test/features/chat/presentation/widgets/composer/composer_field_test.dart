import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The box: one line until there is more to hold, six at most, and a counter
/// that only turns up when the 4096-character cap is in sight (§5.4).
void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  Future<void> pump(WidgetTester tester, {int? length}) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ComposerField(
              controller: controller,
              focusNode: focusNode,
              enabled: true,
              length: length ?? controller.text.length,
            ),
          ),
        ),
      ),
    );
  }

  /// The animated box, not the field inside it: the field reports its
  /// natural height the moment the text changes, and the whole point is that
  /// the box takes a moment to get there.
  double heightOf(WidgetTester tester) => tester
      .getSize(
        find
            .ancestor(
              of: find.byType(TextField),
              matching: find.byType(AnimatedSize),
            )
            .first,
      )
      .height;

  group('growing', () {
    testWidgets('starts at one line', (tester) async {
      await pump(tester);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.minLines, 1);
      expect(field.maxLines, ComposerField.maxLines);
      expect(ComposerField.maxLines, 6);
    });

    testWidgets('grows with the text', (tester) async {
      await pump(tester);
      final one = heightOf(tester);

      controller.text = 'a\nb\nc';
      await pump(tester);
      await tester.pumpAndSettle();

      expect(heightOf(tester), greaterThan(one));
    });

    testWidgets('stops growing at six lines and scrolls instead', (
      tester,
    ) async {
      await pump(tester);

      controller.text = List.filled(6, 'line').join('\n');
      await pump(tester);
      await tester.pumpAndSettle();
      final six = heightOf(tester);

      controller.text = List.filled(30, 'line').join('\n');
      await pump(tester);
      await tester.pumpAndSettle();

      expect(heightOf(tester), six);
    });

    testWidgets('the height change is animated, not a jump', (tester) async {
      await pump(tester);
      final one = heightOf(tester);

      controller.text = 'a\nb\nc\nd';
      await pump(tester);

      // One frame in, the box is on its way rather than already there.
      await tester.pump(const Duration(milliseconds: 40));
      final midway = heightOf(tester);

      await tester.pumpAndSettle();
      final settled = heightOf(tester);

      expect(midway, greaterThan(one));
      expect(midway, lessThan(settled));
    });
  });

  group('the counter', () {
    testWidgets('is absent for an ordinary message', (tester) async {
      await pump(tester, length: 12);

      expect(find.textContaining('left'), findsNothing);
    });

    testWidgets('appears once the cap is in sight', (tester) async {
      await pump(tester, length: MessageLimits.counterVisibleFrom);
      await tester.pumpAndSettle();

      expect(find.text('296 left'), findsOneWidget);
    });

    testWidgets('counts down to the cap', (tester) async {
      await pump(tester, length: MessageLimits.maxContentLength);
      await tester.pumpAndSettle();

      expect(find.text('0 left'), findsOneWidget);
    });

    testWidgets('says how far over the limit the text is', (tester) async {
      await pump(tester, length: MessageLimits.maxContentLength + 17);
      await tester.pumpAndSettle();

      expect(find.text('17 over the limit'), findsOneWidget);
    });

    testWidgets('warms towards the danger colour as the cap approaches', (
      tester,
    ) async {
      Color colour() => tester
          .widget<Text>(
            find.descendant(
              of: find.byType(ComposerCounter),
              matching: find.byType(Text),
            ),
          )
          .style!
          .color!;

      await pump(tester, length: 3850);
      await tester.pumpAndSettle();
      final early = colour();

      await pump(tester, length: 4090);
      await tester.pumpAndSettle();
      final late = colour();

      expect(early, isNot(late));
      expect(late.r, greaterThan(early.r));
    });
  });
}
