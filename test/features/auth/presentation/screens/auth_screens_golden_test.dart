import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/features/auth/presentation/screens/register_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_confirm_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_request_screen.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_buttons.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pump_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Every signed-out form, in every window it can be opened in.
///
/// These screens live outside the app shell — nobody is signed in yet, so
/// there is no rail and no chat list beside them — and each golden is the
/// whole window: a phone, a tablet in portrait, a desktop. On the last two
/// the form sits on a card over the wallpaper.
///
/// The OAuth buttons are switched on here so their layout is checked; the
/// shipped build offers none until the backend's callback can hand the
/// session back (see `oauthProvidersProvider`).
void main() {
  const windows = {
    'phone': Size(390, 844),
    'tablet': Size(800, 1024),
    'desktop': Size(1440, 900),
  };

  late _MockAuthRepository repository;

  setUp(() => repository = _MockAuthRepository());

  /// Pumps [screen]. A [pushed] screen goes over a blank first page, the way
  /// the reset screens are opened from sign-in, so it shows its way back.
  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = const Size(390, 844),
    bool dark = false,
    bool pushed = false,
    List<Override> overrides = const [],
  }) async {
    final navigator = GlobalKey<NavigatorState>();

    await tester.pumpWidgetBuilder(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ...defaultTestOverrides(),
          authRepositoryProvider.overrideWithValue(repository),
          oauthProvidersProvider.overrideWithValue(OAuthProvider.values),
          ...overrides,
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: pushed ? const SizedBox.shrink() : screen,
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    if (pushed) {
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => screen),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> unfocus(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
  }

  testWidgets('sign-in and sign-up open on the logo, with no app bar', (
    tester,
  ) async {
    for (final screen in const [LoginScreen(), RegisterScreen()]) {
      await pumpScreen(tester, screen);

      expect(find.byType(ChatixLogo), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(BackButton), findsNothing);
    }
  });

  testWidgets('a reset screen pushed over sign-in has a way back', (
    tester,
  ) async {
    await pumpScreen(tester, const ResetPasswordRequestScreen(), pushed: true);

    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('the form is never wider than 420 px', (tester) async {
    for (final size in windows.values) {
      await pumpScreen(tester, const LoginScreen(), size: size);

      final field = tester.getSize(find.byType(TextField).first);
      expect(field.width, lessThanOrEqualTo(420), reason: '$size');
    }
  });

  group('goldens', () {
    for (final window in windows.entries) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        final suffix = '${window.key}_${theme.key}';

        testGoldens('login, $suffix', (tester) async {
          await pumpScreen(
            tester,
            const LoginScreen(),
            size: window.value,
            dark: theme.value,
          );
          await screenMatchesGolden(tester, 'login_$suffix');
        });

        // Part of a password typed: four rules ticked, the symbol still
        // missing, the meter on "weak".
        testGoldens('register, $suffix', (tester) async {
          await pumpScreen(
            tester,
            const RegisterScreen(),
            size: window.value,
            dark: theme.value,
          );
          await tester.enterText(find.byType(TextField).at(2), 'Chatix2026');
          await unfocus(tester);
          await screenMatchesGolden(tester, 'register_$suffix');
        });

        testGoldens('reset request, $suffix', (tester) async {
          await pumpScreen(
            tester,
            const ResetPasswordRequestScreen(),
            size: window.value,
            dark: theme.value,
            pushed: true,
          );
          await screenMatchesGolden(tester, 'reset_request_$suffix');
        });

        // Submitted empty: the field errors sit under their fields.
        testGoldens('reset confirm, $suffix', (tester) async {
          await pumpScreen(
            tester,
            const ResetPasswordConfirmScreen(),
            size: window.value,
            dark: theme.value,
            pushed: true,
          );
          final submit = find.byType(FilledButton);
          await tester.ensureVisible(submit);
          await tester.tap(submit);
          await tester.pumpAndSettle();
          await unfocus(tester);
          await screenMatchesGolden(tester, 'reset_confirm_$suffix');
        });
      }
    }

    // "Wrong username or password" under the password, not in a banner.
    for (final theme in {'light': false, 'dark': true}.entries) {
      testGoldens('login refused, phone, ${theme.key}', (tester) async {
        when(
          () => repository.login(
            username: any(named: 'username'),
            password: any(named: 'password'),
          ),
        ).thenAnswer(
          (_) async => const Left(
            ApiFailure(
              code: 'WRONG_LOGIN_DATA',
              message: 'Incorrect username or password',
              detail: {'username': 'ada'},
              status: 400,
            ),
          ),
        );
        await pumpScreen(tester, const LoginScreen(), dark: theme.value);

        await tester.enterText(find.byType(TextField).at(0), 'ada');
        await tester.enterText(find.byType(TextField).at(1), 'secret');
        await tester.tap(find.byType(FilledButton));
        await tester.pumpAndSettle();
        await unfocus(tester);

        await screenMatchesGolden(tester, 'login_refused_phone_${theme.key}');
      });
    }
  });
}
