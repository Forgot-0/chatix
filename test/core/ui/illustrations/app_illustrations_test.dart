import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';

void main() {
  Widget host(Widget child, {Brightness brightness = Brightness.light}) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppIllustration', () {
    for (final kind in AppIllustrationKind.values) {
      testWidgets('${kind.name} paints in both themes', (tester) async {
        for (final brightness in Brightness.values) {
          await tester.pumpWidget(
            host(AppIllustration(kind: kind), brightness: brightness),
          );
          await tester.pump();

          expect(find.byType(CustomPaint), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets('is square, at the size it was asked for', (tester) async {
      await tester.pumpWidget(
        host(const AppIllustration(kind: AppIllustrationKind.people, size: 64)),
      );

      final box = tester.getSize(find.byType(AppIllustration));
      expect(box, const Size(64, 64));
    });

    testWidgets('says nothing to a screen reader', (tester) async {
      // The title and message beside it carry the meaning; a drawing that
      // announced itself would only repeat them.
      await tester.pumpWidget(
        host(const AppIllustration(kind: AppIllustrationKind.messages)),
      );

      expect(
        find.descendant(
          of: find.byType(AppIllustration),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('AppEmptyState', () {
    testWidgets('draws the illustration when it is given one', (tester) async {
      await tester.pumpWidget(
        host(
          const AppEmptyState(
            title: 'No conversations',
            illustration: AppIllustrationKind.conversations,
          ),
        ),
      );

      expect(find.byType(AppIllustration), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(find.text('No conversations'), findsOneWidget);
    });

    testWidgets('falls back to the icon when it is not', (tester) async {
      await tester.pumpWidget(
        host(
          const AppEmptyState(
            title: 'Nothing here',
            icon: Icons.inbox_outlined,
          ),
        ),
      );

      expect(find.byType(AppIllustration), findsNothing);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    });
  });
}
