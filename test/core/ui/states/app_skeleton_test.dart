import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

import 'package:chatix/core/ui/states/app_async_states.dart';

void main() {
  Widget host({required bool reduceMotion, required Widget child}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );
  }

  group('AppSkeleton', () {
    testWidgets('sweeps while motion is allowed', (tester) async {
      await tester.pumpWidget(
        host(
          reduceMotion: false,
          child: const AppSkeleton(child: AppBone(height: 20)),
        ),
      );

      final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
      expect(shimmer.enabled, isTrue);

      // Left running, so it is torn down rather than leaked into the next
      // test.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('holds still when the reader asked it to', (tester) async {
      await tester.pumpWidget(
        host(
          reduceMotion: true,
          child: const AppSkeleton(child: AppBone(height: 20)),
        ),
      );

      final shimmer = tester.widget<Shimmer>(find.byType(Shimmer));
      expect(shimmer.enabled, isFalse);

      // The bones are still drawn: the placeholder is what reserves the
      // space, and reduced motion is not a reason to show less.
      expect(find.byType(AppBone), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('is invisible to a screen reader', (tester) async {
      await tester.pumpWidget(
        host(
          reduceMotion: true,
          child: const AppSkeleton(child: Text('placeholder')),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(AppSkeleton),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );
    });
  });

  group('AppListSkeleton', () {
    testWidgets('lays out the rows it was asked for, and never scrolls', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          reduceMotion: true,
          child: const AppListSkeleton(itemCount: 3, hasTrailing: true),
        ),
      );

      final list = tester.widget<ListView>(find.byType(ListView));
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
      expect(find.byType(AppBone), findsWidgets);
    });
  });
}
