import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_layout.dart';

void main() {
  group('AppBreakpoints.modeFor', () {
    test('a phone is compact', () {
      expect(AppBreakpoints.modeFor(320), AppLayoutMode.compact);
      expect(AppBreakpoints.modeFor(599.9), AppLayoutMode.compact);
    });

    test('a tablet in portrait is medium — rail, but still one pane', () {
      expect(AppBreakpoints.modeFor(600), AppLayoutMode.medium);
      expect(AppBreakpoints.modeFor(834), AppLayoutMode.medium);
      expect(AppBreakpoints.modeFor(899.9), AppLayoutMode.medium);
    });

    test('900 is where the second pane fits', () {
      expect(AppBreakpoints.modeFor(900), AppLayoutMode.expanded);
      expect(AppBreakpoints.modeFor(1440), AppLayoutMode.expanded);
    });

    test('the list pane still leaves a usable chat at the breakpoint', () {
      expect(
        AppBreakpoints.expanded - AppBreakpoints.listPaneWidth,
        greaterThanOrEqualTo(AppBreakpoints.medium - 100),
      );
    });
  });

  group('AppLayoutMode', () {
    test('only compact uses the bottom bar', () {
      expect(AppLayoutMode.compact.usesBottomBar, isTrue);
      expect(AppLayoutMode.medium.usesBottomBar, isFalse);
      expect(AppLayoutMode.expanded.usesBottomBar, isFalse);
    });

    test('the rail covers everything the bottom bar does not', () {
      for (final mode in AppLayoutMode.values) {
        expect(mode.usesRail, !mode.usesBottomBar);
      }
    });

    test('only expanded is two-pane', () {
      expect(AppLayoutMode.expanded.isTwoPane, isTrue);
      expect(AppLayoutMode.medium.isTwoPane, isFalse);
      expect(AppLayoutMode.compact.isTwoPane, isFalse);
    });
  });

  group('AppLayoutScope', () {
    testWidgets('hands the measured mode to descendants', (tester) async {
      late AppLayoutMode seen;

      await tester.pumpWidget(
        AppLayoutScope(
          mode: AppLayoutMode.expanded,
          child: Builder(
            builder: (context) {
              seen = AppLayoutScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(seen, AppLayoutMode.expanded);
    });

    testWidgets('outside the shell, a screen is a single pane', (tester) async {
      late AppLayoutMode seen;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            seen = AppLayoutScope.of(context);
            return const SizedBox();
          },
        ),
      );

      expect(seen, AppLayoutMode.compact);
      expect(seen.isTwoPane, isFalse);
    });
  });
}
