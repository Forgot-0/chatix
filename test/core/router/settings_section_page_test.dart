import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_page_transitions.dart';

/// `AppPageTransitions.section`: a section beside the list it was picked
/// from has no back arrow, and gets it back the moment the window narrows
/// to one pane — without anybody navigating.
void main() {
  late ValueNotifier<AppLayoutMode> mode;
  late GoRouter router;

  setUp(() => mode = ValueNotifier(AppLayoutMode.expanded));
  tearDown(() => mode.dispose());

  Future<void> pump(WidgetTester tester) async {
    router = GoRouter(
      initialLocation: '/list/section',
      routes: [
        ShellRoute(
          builder: (context, state, child) => ValueListenableBuilder(
            valueListenable: mode,
            builder: (context, value, _) =>
                AppLayoutScope(mode: value, child: child),
          ),
          routes: [
            GoRoute(
              path: '/list',
              builder: (_, _) => const Scaffold(body: Text('list')),
              routes: [
                GoRoute(
                  path: 'section',
                  pageBuilder: (context, state) =>
                      AppPageTransitions.section<void>(
                        key: state.pageKey,
                        besideList: AppLayoutScope.of(context).isTwoPane,
                        child: Scaffold(
                          appBar: AppBar(title: const Text('section')),
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('beside the list: no back arrow, though a page is under it', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('section'), findsOneWidget);
    expect(router.canPop(), isTrue);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('one pane: the arrow is back, and still leads to the list', (
    tester,
  ) async {
    await pump(tester);

    mode.value = AppLayoutMode.compact;
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
  });

  testWidgets('widening again takes it away again', (tester) async {
    await pump(tester);

    mode.value = AppLayoutMode.medium;
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);

    mode.value = AppLayoutMode.expanded;
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
  });
}
