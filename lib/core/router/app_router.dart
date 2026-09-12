import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_page_transitions.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/router/app_shell.dart';
import 'package:chatix/core/router/chats_pane_shell.dart';
import 'package:chatix/core/router/locale_aware_router.dart';
import 'package:chatix/examples/localization_assets_demo.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/features/auth/presentation/screens/oauth_callback_screen.dart';
import 'package:chatix/features/auth/presentation/screens/register_screen.dart';
import 'package:chatix/features/auth/presentation/screens/sessions_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_confirm_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_request_screen.dart';
import 'package:chatix/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:chatix/features/chat/presentation/screens/call_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chat_detail_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chat_info_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chat_members_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chat_search_screen.dart';
import 'package:chatix/features/chat/presentation/screens/create_chat_screen.dart';
import 'package:chatix/features/chat_organizer/presentation/screens/chat_folders_screen.dart';
import 'package:chatix/features/chat_organizer/presentation/screens/folder_editor_screen.dart';
import 'package:chatix/features/notification/presentation/screens/notifications_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profiles_list_screen.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';
import 'package:chatix/features/ui_showcase/ui_showcase.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A page that slides in on the horizontal axis: forward inside a section.
Page<void> _push(GoRouterState state, Widget child) {
  return AppPageTransitions.sharedAxisHorizontal<void>(
    key: state.pageKey,
    name: state.name ?? state.fullPath,
    child: child,
  );
}

/// A page that fades through: the root of a tab, which has no neighbours to
/// slide away from.
Page<void> _root(GoRouterState state, Widget child) {
  return AppPageTransitions.fadeThrough<void>(
    key: state.pageKey,
    name: state.name ?? state.fullPath,
    child: child,
  );
}

final routerProvider = Provider<GoRouter>((ref) {
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
    navigatorKey: _rootNavigatorKey,
    refreshListenable: authListenable,
    observers: [ref.read(localizationRouterObserverProvider)],
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      return resolveAuthRedirect(
        location: state.matchedLocation,
        isSessionUnresolved: authState.isSessionUnresolved,
        isAuthenticated: authState.isAuthenticated,
      );
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          // ── Chats ──────────────────────────────────────────────────────
          //
          // A nested ShellRoute wraps the whole branch so the layout can be
          // decided in one place: on a wide window it pulls the list out to
          // the left and leaves this navigator — the chat, its members, its
          // info — as the right pane. The chat that is open is the one in the
          // URL, so flipping between one and two panes never loses it.
          StatefulShellBranch(
            routes: [
              ShellRoute(
                builder: (context, state, child) => ChatsPaneShell(
                  selectedChatId: ChatDetailRoute.idFrom(state),
                  child: child,
                ),
                routes: [
                  GoRoute(
                    path: ChatsRoute.path,
                    name: RouteNames.chats,
                    pageBuilder: (context, state) =>
                        _root(state, const ChatsListPane()),
                    routes: [
                      GoRoute(
                        path: CreateChatRoute.path,
                        name: RouteNames.createChat,
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) => _push(
                          state,
                          CreateChatScreen(
                            initialType: CreateChatRoute.typeFrom(state),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: ChatSearchRoute.path,
                        name: RouteNames.chatSearch,
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) =>
                            _push(state, const ChatSearchScreen()),
                      ),
                      GoRoute(
                        path: ChatFoldersRoute.path,
                        name: RouteNames.chatFolders,
                        parentNavigatorKey: _rootNavigatorKey,
                        pageBuilder: (context, state) =>
                            _push(state, const ChatFoldersScreen()),
                        routes: [
                          GoRoute(
                            path: FolderEditorRoute.path,
                            name: RouteNames.folderEditor,
                            parentNavigatorKey: _rootNavigatorKey,
                            pageBuilder: (context, state) => _push(
                              state,
                              FolderEditorScreen(
                                folderId: FolderEditorRoute.folderIdFrom(state),
                              ),
                            ),
                          ),
                        ],
                      ),
                      GoRoute(
                        path: ChatDetailRoute.path,
                        name: RouteNames.chatDetail,
                        pageBuilder: (context, state) {
                          final chatId = ChatDetailRoute.idFrom(state);
                          if (chatId == null) {
                            return _push(state, const _UnknownChatScreen());
                          }
                          return _push(
                            state,
                            ChatDetailScreen(
                              chatId: chatId,
                              focusMessageId: ChatDetailRoute.messageIdFrom(
                                state,
                              ),
                              focusMessageSeq: ChatDetailRoute.messageSeqFrom(
                                state,
                              ),
                            ),
                          );
                        },
                        routes: [
                          GoRoute(
                            path: ChatMembersRoute.path,
                            name: RouteNames.chatMembers,
                            pageBuilder: (context, state) {
                              final chatId = ChatDetailRoute.idFrom(state);
                              if (chatId == null) {
                                return _push(state, const _UnknownChatScreen());
                              }
                              return _push(
                                state,
                                ChatMembersScreen(chatId: chatId),
                              );
                            },
                          ),
                          GoRoute(
                            path: ChatInfoRoute.path,
                            name: RouteNames.chatInfo,
                            pageBuilder: (context, state) {
                              final chatId = ChatDetailRoute.idFrom(state);
                              if (chatId == null) {
                                return _push(state, const _UnknownChatScreen());
                              }
                              return _push(
                                state,
                                ChatInfoScreen(chatId: chatId),
                              );
                            },
                          ),
                          // A call takes over the screen: no shell, no panes.
                          GoRoute(
                            path: ChatCallRoute.path,
                            name: RouteNames.chatCall,
                            parentNavigatorKey: _rootNavigatorKey,
                            pageBuilder: (context, state) {
                              final chatId = ChatDetailRoute.idFrom(state);
                              if (chatId == null) {
                                return _push(state, const _UnknownChatScreen());
                              }
                              return _push(state, CallScreen(chatId: chatId));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // ── Contacts ───────────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ProfilesRoute.path,
                name: RouteNames.profiles,
                pageBuilder: (context, state) =>
                    _root(state, const ProfilesListScreen()),
                routes: [
                  GoRoute(
                    path: ProfileDetailRoute.path,
                    name: RouteNames.profileDetail,
                    pageBuilder: (context, state) {
                      final profileId = ProfileDetailRoute.idFrom(state);
                      if (profileId == null) {
                        return _push(state, const _UnknownProfileScreen());
                      }
                      return _push(state, ProfileScreen(profileId: profileId));
                    },
                  ),
                ],
              ),
            ],
          ),

          // ── Notifications ──────────────────────────────────────────────
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: NotificationsRoute.path,
                name: RouteNames.notifications,
                pageBuilder: (context, state) =>
                    _root(state, const NotificationsScreen()),
              ),
            ],
          ),

          // ── Settings ───────────────────────────────────────────────────
          //
          // The account lives here now that the profile tab is gone: /profile
          // is a second top-level route of this branch, so opening it selects
          // the settings tab rather than dropping the shell entirely.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SettingsRoute.path,
                name: RouteNames.settings,
                pageBuilder: (context, state) =>
                    _root(state, const SettingsScreen()),
                routes: [
                  GoRoute(
                    path: LanguageSettingsRoute.path,
                    name: RouteNames.languageSettings,
                    pageBuilder: (context, state) =>
                        _push(state, const LanguageSettingsScreen()),
                  ),
                  GoRoute(
                    path: SessionsRoute.path,
                    name: RouteNames.sessions,
                    pageBuilder: (context, state) =>
                        _push(state, const SessionsScreen()),
                  ),
                ],
              ),
              GoRoute(
                path: ProfileRoute.path,
                name: RouteNames.profile,
                pageBuilder: (context, state) =>
                    _push(state, const ProfileScreen()),
                routes: [
                  GoRoute(
                    path: ProfileEditRoute.path,
                    name: RouteNames.profileEdit,
                    pageBuilder: (context, state) =>
                        _push(state, const ProfileEditScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Demo-only surface from lib/examples. Kept for reference but excluded
      // from release builds: `kDebugMode` is a compile-time constant, so the
      // route and everything it pulls in is tree-shaken out of a release.
      if (kDebugMode)
        GoRoute(
          path: LocalizationAssetsDemoRoute.path,
          name: RouteNames.localizationAssetsDemo,
          builder: (context, state) => const LocalizationAssetsDemo(),
        ),

      // The design-system showcase: a developer surface for checking tokens
      // against both themes, tree-shaken out of release alongside the demos.
      if (kDebugMode)
        GoRoute(
          path: ComponentShowcaseRoute.path,
          name: RouteNames.componentShowcase,
          builder: (context, state) => const ComponentShowcaseScreen(),
        ),

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

      GoRoute(
        path: OAuthCallbackRoute.path,
        name: RouteNames.oauthCallback,
        builder: (context, state) =>
            OAuthCallbackScreen(error: state.uri.queryParameters['error']),
      ),

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

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

String? resolveAuthRedirect({
  required String location,
  required bool isSessionUnresolved,
  required bool isAuthenticated,
}) {
  if (isSessionUnresolved) return null;

  final isPublic = isPublicLocation(location);

  if (!isAuthenticated) {
    if (isPublic) return null;
    return LoginRoute.location;
  }

  if (location == LoginRoute.path || location == RegisterRoute.path) {
    return ChatsRoute.location;
  }

  return null;
}

class _SessionLoadingScreen extends StatelessWidget {
  const _SessionLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _UnknownChatScreen extends StatelessWidget {
  const _UnknownChatScreen();

  @override
  Widget build(BuildContext context) =>
      _InvalidRouteScreen(message: AppLocalizations.of(context).unknownChat);
}

class _UnknownProfileScreen extends StatelessWidget {
  const _UnknownProfileScreen();

  @override
  Widget build(BuildContext context) =>
      _InvalidRouteScreen(message: AppLocalizations.of(context).unknownProfile);
}

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
              child: Text(AppLocalizations.of(context).goToChats),
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
      appBar: AppBar(title: Text(AppLocalizations.of(context).pageNotFound)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '404',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).pathDoesNotExist(uri.path)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(ChatsRoute.location),
              child: Text(AppLocalizations.of(context).goToChats),
            ),
          ],
        ),
      ),
    );
  }
}
