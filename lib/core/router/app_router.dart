import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/providers/localization_providers.dart';
import 'package:chatix/core/router/locale_aware_router.dart';
import 'package:chatix/examples/localization_assets_demo.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/features/auth/presentation/screens/register_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_confirm_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_request_screen.dart';
import 'package:chatix/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:chatix/features/home/presentation/screens/home_screen.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profiles_list_screen.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/features/chat/presentation/screens/chat_screen.dart';
import 'package:chatix/features/survey/presentation/screens/survey_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  // Watch for locale changes - this rebuilds the router when locale changes
  ref.watch(persistentLocaleProvider);

  // Create a router with locale awareness
  return GoRouter(
    initialLocation: AppConstants.initialRoute,
    debugLogDiagnostics: true,
    // Add the observer for locale awareness
    observers: [ref.read(localizationRouterObserverProvider)],
    redirect: (context, state) {
      // While AuthController.build() is still resolving a stored token
      // (app cold start) or a login/register/logout call is in flight,
      // don't force a redirect based on a not-yet-settled auth state —
      // otherwise a returning user with a valid token flashes through the
      // login screen before bouncing back to home. (The initial '/' route
      // below still has to make an immediate choice since it has no
      // builder of its own — that one small flash on cold start is a known
      // limitation, to be addressed with a proper splash route in the
      // fuller routing pass.)
      if (authState.isLoading) {
        return null;
      }

      // Get the authentication status
      final isLoggedIn = authState.isAuthenticated;

      // Check if the user is going to the login page
      final isGoingToLogin = state.matchedLocation == AppConstants.loginRoute;

      // Check if the user is going to the register page
      final isGoingToRegister =
          state.matchedLocation == AppConstants.registerRoute;

      // Email verification / password reset are reachable whether or not
      // the person is currently logged in (e.g. a logged-in user can still
      // want to verify their email or reset a forgotten password).
      final isGoingToPublicAuthFlow = isGoingToLogin ||
          isGoingToRegister ||
          state.matchedLocation == AppConstants.verifyEmailRoute ||
          state.matchedLocation == AppConstants.resetPasswordRequestRoute ||
          state.matchedLocation == AppConstants.resetPasswordConfirmRoute;

      // If not logged in and not going to a public auth screen, redirect to login
      if (!isLoggedIn && !isGoingToPublicAuthFlow) {
        return AppConstants.loginRoute;
      }

      // If logged in and going to login/register, redirect to home
      if (isLoggedIn && (isGoingToLogin || isGoingToRegister)) {
        return AppConstants.homeRoute;
      }

      // No redirect needed
      return null;
    },
    routes: [
      // Home route
      GoRoute(
        path: AppConstants.homeRoute,
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Login route
      GoRoute(
        path: AppConstants.loginRoute,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Register route
      GoRoute(
        path: AppConstants.registerRoute,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),

      // Verify email route
      GoRoute(
        path: AppConstants.verifyEmailRoute,
        name: 'verify_email',
        builder: (context, state) => const VerifyEmailScreen(),
      ),

      // Reset password — request a code
      GoRoute(
        path: AppConstants.resetPasswordRequestRoute,
        name: 'reset_password_request',
        builder: (context, state) => const ResetPasswordRequestScreen(),
      ),

      // Reset password — confirm code + new password
      GoRoute(
        path: AppConstants.resetPasswordConfirmRoute,
        name: 'reset_password_confirm',
        builder: (context, state) => const ResetPasswordConfirmScreen(),
      ),

      // Settings route
      GoRoute(
        path: AppConstants.settingsRoute,
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),

      // Language settings route
      GoRoute(
        path: AppConstants.languageSettingsRoute,
        name: 'language_settings',
        builder: (context, state) => const LanguageSettingsScreen(),
      ),

      // Localization Assets Demo route
      GoRoute(
        path: AppConstants.localizationAssetsDemoRoute,
        name: 'localization_assets_demo',
        builder: (context, state) => const LocalizationAssetsDemo(),
      ),

      // Chat route
      GoRoute(
        path: AppConstants.chatRoute,
        name: 'chat',
        builder: (context, state) => const ChatScreen(),
      ),

      // Survey route
      GoRoute(
        path: AppConstants.surveyRoute,
        name: 'survey',
        builder: (context, state) => const SurveyScreen(),
      ),

      // Profile route — the signed-in person's own profile, with 'edit'
      // and ':id' nested underneath. Nesting (rather than 3 flat sibling
      // routes) matters here: go_router matches a static child path
      // ('edit') before a dynamic one (':id') at the same level
      // regardless of declaration order, guaranteeing '/profile/edit'
      // can never be captured as profileId "edit" by the ':id' route —
      // that guarantee does NOT hold for flat top-level routes, which
      // are matched in declaration order instead.
      GoRoute(
        path: AppConstants.profileRoute,
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
        routes: [
          // Edit the signed-in person's own profile: '/profile/edit'.
          GoRoute(
            path: 'edit',
            name: 'profile_edit',
            builder: (context, state) => const ProfileEditScreen(),
          ),

          // Someone else's profile, by id: '/profile/{id}'.
          GoRoute(
            path: ':id',
            name: 'profile_detail',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return ProfileScreen(profileId: id);
            },
          ),
        ],
      ),

      // Browse/search all profiles.
      GoRoute(
        path: AppConstants.profilesListRoute,
        name: 'profiles_list',
        builder: (context, state) => const ProfilesListScreen(),
      ),

      // Initial route - redirects based on auth state
      GoRoute(
        path: AppConstants.initialRoute,
        name: 'initial',
        redirect: (context, state) => authState.isAuthenticated
            ? AppConstants.homeRoute
            : AppConstants.loginRoute,
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '404',
              style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Page ${state.uri.path} not found'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppConstants.homeRoute),
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    ),
  );
});
