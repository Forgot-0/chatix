import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/router/app_shell.dart';
import 'package:chatix/core/router/locale_aware_router.dart';
import 'package:chatix/examples/localization_assets_demo.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/features/auth/presentation/screens/oauth_callback_screen.dart';
import 'package:chatix/features/auth/presentation/screens/register_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_confirm_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_request_screen.dart';
import 'package:chatix/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:chatix/features/chat/presentation/screens/call_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chat_members_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat/presentation/screens/create_chat_screen.dart';
import 'package:chatix/features/notification/presentation/screens/notifications_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profiles_list_screen.dart';
import 'package:chatix/features/project/presentation/screens/create_project_screen.dart';
import 'package:chatix/features/project/presentation/screens/my_applications_screen.dart';
import 'package:chatix/features/project/presentation/screens/my_invites_screen.dart';
import 'package:chatix/features/project/presentation/screens/my_projects_screen.dart';
import 'package:chatix/features/project/presentation/screens/position_detail_screen.dart';
import 'package:chatix/features/project/presentation/screens/project_detail_screen.dart';
import 'package:chatix/features/project/presentation/screens/projects_list_screen.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';

/// The app's route table.
///
/// ### Shape
///
/// One `StatefulShellRoute.indexedStack` holding the four tabbed areas
/// (Chats / Projects / Notifications / Profile), and a set of flat routes for
/// everything you *enter* rather than *switch to* — a conversation, a project,
/// a position, someone else's profile, settings, the auth flow. Flat routes
/// are pushed above the shell, so they cover the navigation bar: a full-screen
/// conversation whose tab bar could switch out from under it is how a
/// half-typed message gets lost.
///
/// ### The redirect
///
/// Unchanged in spirit from the previous version — a single `redirect`
/// callback driven by `authProvider`, holding its decision while the session
/// is still resolving, sending signed-out users to `/login` and signed-in
/// users away from it. Two things did change:
///
/// * the public set now covers the whole auth flow, including
///   `/oauth-callback` (see [OAuthCallbackRoute] for why it is whitelisted
///   before the screen exists);
/// * the decision logic is extracted into [resolveAuthRedirect], a pure
///   function, so the "session died mid-session" behaviour is unit-testable
///   without a widget tree.
///
/// ### Why `refreshListenable` and not `ref.watch`
///
/// `ref.watch(authProvider)` inside this provider would rebuild the whole
/// `GoRouter` on every auth change. A new `GoRouter` starts from
/// `initialLocation` with an empty history — so a token refresh, or any
/// state flip, would silently throw away the user's navigation stack. Feeding
/// auth changes into a `Listenable` instead keeps one router instance for the
/// app's lifetime and merely asks it to re-evaluate `redirect`, which is
/// exactly the amount of work the situation calls for.
final routerProvider = Provider<GoRouter>((ref) {
  // Bridges riverpod → Listenable. `fireImmediately` is not needed: the
  // router evaluates `redirect` on its first navigation anyway, and the
  // redirect reads the current state directly.
  final authListenable = ValueNotifier<AsyncValue<UserEntity?>>(
    const AsyncValue.loading(),
  );
  ref.onDispose(authListenable.dispose);
  ref.listen<AsyncValue<UserEntity?>>(
    authProvider,
    (previous, next) => authListenable.value = next,
    fireImmediately: true,
  );

  return GoRouter(
    initialLocation: SplashRoute.location,
    debugLogDiagnostics: true,
    // Required for `parentNavigatorKey: _rootNavigatorKey` below to resolve —
    // that is what lets a detail route be pushed *over* the shell instead of
    // inside the active branch.
    navigatorKey: _rootNavigatorKey,
    refreshListenable: authListenable,
    observers: [ref.read(localizationRouterObserverProvider)],
    redirect: (context, state) {
      // Read, don't watch: watching here would rebuild the provider (and the
      // router with it). The `refreshListenable` above is what makes this
      // callback run again when the session changes.
      final authState = ref.read(authProvider);
      return resolveAuthRedirect(
        location: state.matchedLocation,
        isSessionUnresolved: authState.isSessionUnresolved,
        isAuthenticated: authState.isAuthenticated,
      );
    },
    routes: [
      // ---------------------------------------------------------------
      // The signed-in frame: four branches, one persistent bottom bar.
      // ---------------------------------------------------------------
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // --- Chats -------------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ChatsRoute.path,
                name: RouteNames.chats,
                builder: (context, state) => const ChatsListScreen(),
                routes: [
                  // Static child before the dynamic one — go_router prefers a
                  // static sibling, so 'create' can never be read as a chat id.
                  GoRoute(
                    path: CreateChatRoute.path,
                    name: RouteNames.createChat,
                    // `parentNavigatorKey` puts the form above the shell: it's
                    // a task you finish or abandon, not a place to tab away
                    // from mid-way.
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CreateChatScreen(),
                  ),
                  GoRoute(
                    path: ChatDetailRoute.path,
                    name: RouteNames.chatDetail,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final chatId = ChatDetailRoute.idFrom(state);
                      if (chatId == null) {
                        return const _InvalidRouteScreen(message: 'Unknown chat');
                      }
                      return ChatDetailScreen(chatId: chatId);
                    },
                    routes: [
                      GoRoute(
                        path: ChatMembersRoute.path,
                        name: RouteNames.chatMembers,
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final chatId = ChatDetailRoute.idFrom(state);
                          if (chatId == null) {
                            return const _InvalidRouteScreen(
                              message: 'Unknown chat',
                            );
                          }
                          return ChatMembersScreen(chatId: chatId);
                        },
                      ),
                      GoRoute(
                        path: ChatCallRoute.path,
                        name: RouteNames.chatCall,
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final chatId = ChatDetailRoute.idFrom(state);
                          if (chatId == null) {
                            return const _InvalidRouteScreen(
                              message: 'Unknown chat',
                            );
                          }
                          return CallScreen(chatId: chatId);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // --- Projects ----------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProjectsRoute.path,
                name: RouteNames.projects,
                builder: (context, state) => const ProjectsListScreen(),
                routes: [
                  GoRoute(
                    path: MyProjectsRoute.path,
                    name: RouteNames.myProjects,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MyProjectsScreen(),
                  ),
                  GoRoute(
                    path: CreateProjectRoute.path,
                    name: RouteNames.createProject,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CreateProjectScreen(),
                  ),
                  GoRoute(
                    path: MyInvitesRoute.path,
                    name: RouteNames.myInvites,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MyInvitesScreen(),
                  ),
                  GoRoute(
                    path: ProjectDetailRoute.path,
                    name: RouteNames.projectDetail,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final projectId = ProjectDetailRoute.idFrom(state);
                      if (projectId == null) {
                        return const _InvalidRouteScreen(
                          message: 'Unknown project',
                        );
                      }
                      return ProjectDetailScreen(projectId: projectId);
                    },
                    routes: [
                      // /projects/{projectId}/positions/{positionId}
                      GoRoute(
                        path: PositionDetailRoute.path,
                        name: RouteNames.positionDetail,
                        parentNavigatorKey: _rootNavigatorKey,
                        builder: (context, state) {
                          final route = PositionDetailRoute.from(state);
                          if (route == null) {
                            return const _InvalidRouteScreen(
                              message: 'Unknown position',
                            );
                          }
                          return PositionDetailScreen(
                            projectId: route.projectId,
                            positionId: route.positionId,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // --- Notifications -----------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: NotificationsRoute.path,
                name: RouteNames.notifications,
                // No ':id' child: a notification is not a destination, it
                // points at one — the tap handler resolves its `payload` to a
                // chat/project route (see `resolveNotificationRoute`).
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),

          // --- Profile -----------------------------------------------
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfileRoute.path,
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: ProfileEditRoute.path,
                    name: RouteNames.profileEdit,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ProfileEditScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ---------------------------------------------------------------
      // Flat routes — pushed over the shell.
      // ---------------------------------------------------------------

      // The candidate's own applications: spans every project they applied
      // to, so it belongs to none of them.
      GoRoute(
        path: MyApplicationsRoute.path,
        name: RouteNames.myApplications,
        builder: (context, state) => const MyApplicationsScreen(),
      ),

      // Other people's profiles live in their own collection, so that
      // '/profile' can stay unambiguously "mine" (and keep an 'edit' child
      // with no risk of it being parsed as an id).
      GoRoute(
        path: ProfilesRoute.path,
        name: RouteNames.profiles,
        builder: (context, state) => const ProfilesListScreen(),
        routes: [
          GoRoute(
            path: ProfileDetailRoute.path,
            name: RouteNames.profileDetail,
            builder: (context, state) {
              final profileId = ProfileDetailRoute.idFrom(state);
              if (profileId == null) {
                return const _InvalidRouteScreen(message: 'Unknown profile');
              }
              return ProfileScreen(profileId: profileId);
            },
          ),
        ],
      ),

      GoRoute(
        path: SettingsRoute.path,
        name: RouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: LanguageSettingsRoute.path,
            name: RouteNames.languageSettings,
            builder: (context, state) => const LanguageSettingsScreen(),
          ),
        ],
      ),

      GoRoute(
        path: LocalizationAssetsDemoRoute.path,
        name: RouteNames.localizationAssetsDemo,
        builder: (context, state) => const LocalizationAssetsDemo(),
      ),

      // ---------------------------------------------------------------
      // Public auth flow.
      // ---------------------------------------------------------------
      GoRoute(
        path: LoginRoute.path,
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RegisterRoute.path,
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: VerifyEmailRoute.path,
        name: RouteNames.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: ResetPasswordRoute.path,
        name: RouteNames.resetPasswordRequest,
        builder: (context, state) => const ResetPasswordRequestScreen(),
        routes: [
          GoRoute(
            path: ResetPasswordConfirmRoute.path,
            name: RouteNames.resetPasswordConfirm,
            builder: (context, state) => const ResetPasswordConfirmScreen(),
          ),
        ],
      ),

      // The provider redirect lands here (api-docs §3.8 step 3). Registered
      // even though the token hand-back isn't wired yet: the path is already
      // in `publicRoutePrefixes`, and a whitelisted path with no route is a
      // 404 page shown to a user who did nothing wrong. See
      // [OAuthCallbackScreen] for why it stops short of consuming a token.
      GoRoute(
        path: OAuthCallbackRoute.path,
        name: RouteNames.oauthCallback,
        builder: (context, state) =>
            OAuthCallbackScreen(error: state.uri.queryParameters['error']),
      ),

      // ---------------------------------------------------------------
      // '/' — no screen of its own; the redirect above resolves it as soon
      // as the session is known. Reaching the builder means auth settled to
      // "signed in" between the redirect and the build, so send them to the
      // first tab.
      // ---------------------------------------------------------------
      GoRoute(
        path: SplashRoute.path,
        name: RouteNames.splash,
        redirect: (context, state) {
          final authState = ref.read(authProvider);
          if (authState.isSessionUnresolved) return null;
          return authState.isAuthenticated
              ? ChatsRoute.location
              : LoginRoute.location;
        },
        builder: (context, state) => const _SessionLoadingScreen(),
      ),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(uri: state.uri),
  );
});

/// The root navigator, so that a flat/detail route can be pushed **over** the
/// shell rather than inside a branch.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Where the router should send someone standing at [location], or `null` to
/// let them stay.
///
/// Extracted from the `redirect` callback so the whole policy — including the
/// "session expired mid-use" path, which is otherwise awkward to reach — can
/// be tested as a pure function. There is no `BuildContext`, no `GoRouter`,
/// and no widget tree involved in the decision; that is the point.
///
/// ### The rules
///
/// 1. **Session not resolved yet** → stay put. On a cold start the stored
///    token is being exchanged for a `GET /users/me/`; deciding now would
///    flash a returning user through `/login` and immediately back.
/// 2. **Signed out, heading somewhere private** → `/login`.
/// 3. **Signed in, heading for `/login` or `/register`** → the first tab.
///    Only those two: a signed-in user may legitimately open
///    `/verify-email` or `/reset-password`.
/// 4. Otherwise stay put.
///
/// Rule 2 is what makes an expired session self-correcting. Nothing in a
/// screen has to notice a 401: `AuthInterceptor` fires the session-expired
/// signal, `AuthController` flips to signed-out, the router's
/// `refreshListenable` fires, this function runs for whatever location the
/// user is on, and they land on `/login` — identically from a chat, a project
/// detail, or a background-triggered navigation.
String? resolveAuthRedirect({
  required String location,
  required bool isSessionUnresolved,
  required bool isAuthenticated,
}) {
  if (isSessionUnresolved) return null;

  final isPublic = isPublicLocation(location);

  if (!isAuthenticated) {
    // '/' has its own redirect and would otherwise be sent to '/login' twice.
    if (isPublic) return null;
    return LoginRoute.location;
  }

  // Signed in: bounce off the two screens that exist to get you signed in.
  if (location == LoginRoute.path || location == RegisterRoute.path) {
    return ChatsRoute.location;
  }

  return null;
}

/// Shown for the instant `/` is on screen before the redirect resolves.
class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

/// Shown when a route matched structurally but its path parameter is unusable
/// (an empty `:chatId`, a non-numeric `:projectId`). Distinct from a 404: the
/// URL *is* a known route, so "page not found" would be misleading — and
/// building the real screen with a bad id would fire a request guaranteed to
/// fail, then show that failure as if the server were at fault.
class _InvalidRouteScreen extends StatelessWidget {
  const _InvalidRouteScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 48),
            const SizedBox(height: 12),
            Text(message),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(ChatsRoute.location),
              child: const Text('Go to chats'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '404',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('${uri.path} does not exist'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(ChatsRoute.location),
              child: const Text('Go to chats'),
            ),
          ],
        ),
      ),
    );
  }
}
