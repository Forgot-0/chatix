import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';

/// The typed route layer: does a `Route(...).location` round-trip back into
/// the *same, correctly typed* id when go_router parses it?
///
/// This is the failure the typed classes exist to prevent. `'/projects/$id'`
/// with a position's UUID in `$id` compiles, matches, and then asks the API
/// for a project that doesn't exist — a runtime 404 for what is really a type
/// error. The tests below drive the real path patterns through a real
/// `GoRouter`, so a pattern and its parser can never quietly disagree.
void main() {
  /// Builds a router over the real path constants and records what each
  /// builder parsed out of the state.
  ///
  /// The nesting mirrors the app's table on purpose: `:chatId` and `create`
  /// are siblings under `/chats`, `positions/:positionId` sits under
  /// `/projects/:projectId`. Flattening it here would test a different
  /// matcher than the one that ships.
  ({GoRouter router, List<Object?> parsed}) buildRouter() {
    final parsed = <Object?>[];

    final router = GoRouter(
      initialLocation: ChatsRoute.path,
      routes: [
        GoRoute(
          path: ChatsRoute.path,
          builder: (_, _) => const Placeholder(),
          routes: [
            GoRoute(
              path: CreateChatRoute.path,
              builder: (_, _) {
                parsed.add('create-chat');
                return const Placeholder();
              },
            ),
            GoRoute(
              path: ChatDetailRoute.path,
              builder: (_, state) {
                parsed.add(ChatDetailRoute.idFrom(state));
                return const Placeholder();
              },
            ),
          ],
        ),
        GoRoute(
          path: ProjectsRoute.path,
          builder: (_, _) => const Placeholder(),
          routes: [
            GoRoute(
              path: MyProjectsRoute.path,
              builder: (_, _) {
                parsed.add('my-projects');
                return const Placeholder();
              },
            ),
            GoRoute(
              path: ProjectDetailRoute.path,
              builder: (_, state) {
                parsed.add(ProjectDetailRoute.idFrom(state));
                return const Placeholder();
              },
              routes: [
                GoRoute(
                  path: PositionDetailRoute.path,
                  builder: (_, state) {
                    final route = PositionDetailRoute.from(state);
                    parsed.add(
                      route == null
                          ? null
                          : (route.projectId, route.positionId),
                    );
                    return const Placeholder();
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: ProfilesRoute.path,
          builder: (_, _) => const Placeholder(),
          routes: [
            GoRoute(
              path: ProfileDetailRoute.path,
              builder: (_, state) {
                parsed.add(ProfileDetailRoute.idFrom(state));
                return const Placeholder();
              },
            ),
          ],
        ),
        GoRoute(
          path: NotificationsRoute.path,
          builder: (_, _) {
            parsed.add('notifications');
            return const Placeholder();
          },
        ),
      ],
    );

    return (router: router, parsed: parsed);
  }

  Future<List<Object?>> go(WidgetTester tester, String location) async {
    final harness = buildRouter();
    addTearDown(harness.router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: harness.router));
    harness.router.go(location);
    await tester.pumpAndSettle();
    return harness.parsed;
  }

  group('locations are built from the typed constructors', () {
    test('chat ids stay strings, project and profile ids stay ints', () {
      expect(const ChatDetailRoute('9f8e-uuid').location, '/chats/9f8e-uuid');
      expect(const ProjectDetailRoute(42).location, '/projects/42');
      expect(const ProfileDetailRoute(17).location, '/profiles/17');
      expect(
        const PositionDetailRoute(projectId: 42, positionId: 'a1b2-uuid')
            .location,
        '/projects/42/positions/a1b2-uuid',
      );
      expect(ChatMembersRoute.locationOf('9f8e'), '/chats/9f8e/members');
      expect(ChatCallRoute.locationOf('9f8e'), '/chats/9f8e/call');
    });
  });

  group('/chats/:chatId', () {
    testWidgets('hands the screen the UUID string, unparsed', (tester) async {
      final parsed = await go(
        tester,
        const ChatDetailRoute('7c0b1f2e-uuid').location,
      );
      expect(parsed, ['7c0b1f2e-uuid']);
    });

    testWidgets('the static "create" child wins over :chatId', (tester) async {
      // Declaration order must not decide this. If it ever does, "New chat"
      // silently becomes a request for a chat whose id is "create".
      final parsed = await go(tester, CreateChatRoute.location);
      expect(parsed, ['create-chat']);
    });
  });

  group('/projects/:projectId', () {
    testWidgets('parses the int id', (tester) async {
      final parsed = await go(tester, const ProjectDetailRoute(42).location);
      expect(parsed, [42]);
    });

    testWidgets('a non-numeric id parses to null, not a crash', (
      tester,
    ) async {
      // A stale or hand-typed link. The route builder is expected to show the
      // "bad link" screen rather than fire a guaranteed-404 request.
      final parsed = await go(tester, '/projects/not-a-number');
      expect(parsed, [null]);
    });

    testWidgets('the static "my" child wins over :projectId', (tester) async {
      final parsed = await go(tester, MyProjectsRoute.location);
      expect(parsed, ['my-projects']);
    });
  });

  group('/projects/:projectId/positions/:positionId', () {
    testWidgets('carries both ids, each with its own type', (tester) async {
      final parsed = await go(
        tester,
        const PositionDetailRoute(
          projectId: 42,
          positionId: 'a1b2c3-uuid',
        ).location,
      );
      expect(parsed, [(42, 'a1b2c3-uuid')]);
    });

    testWidgets('a bad project id invalidates the whole pair', (tester) async {
      final parsed = await go(tester, '/projects/oops/positions/a1b2c3-uuid');
      expect(parsed, [null]);
    });
  });

  group('/profiles/:profileId', () {
    testWidgets('parses the int id', (tester) async {
      final parsed = await go(tester, const ProfileDetailRoute(17).location);
      expect(parsed, [17]);
    });
  });

  group('/notifications', () {
    testWidgets('takes no parameters', (tester) async {
      final parsed = await go(tester, NotificationsRoute.location);
      expect(parsed, ['notifications']);
    });
  });
}
