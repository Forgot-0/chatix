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
import 'package:chatix/features/chat/presentation/screens/chat_search_screen.dart';
import 'package:chatix/features/chat/presentation/screens/chats_list_screen.dart';
import 'package:chatix/features/chat/presentation/screens/create_chat_screen.dart';
import 'package:chatix/features/notification/presentation/screens/notifications_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profiles_list_screen.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';

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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: ChatsRoute.path,
                name: RouteNames.chats,
                builder: (context, state) => const ChatsListScreen(),
                routes: [
                  GoRoute(
                    path: CreateChatRoute.path,
                    name: RouteNames.createChat,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const CreateChatScreen(),
                  ),
                  GoRoute(
                    path: ChatSearchRoute.path,
                    name: RouteNames.chatSearch,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const ChatSearchScreen(),
                  ),
                  GoRoute(
                    path: ChatDetailRoute.path,
                    name: RouteNames.chatDetail,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final chatId = ChatDetailRoute.idFrom(state);
                      if (chatId == null) {
                        return const _InvalidRouteScreen(
                          message: 'Unknown chat',
                        );
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

          StatefulShellBranch(
            routes: [
              GoRoute(
                path: NotificationsRoute.path,
                name: RouteNames.notifications,
                builder: (context, state) => const NotificationsScreen(),
              ),
            ],
          ),

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
