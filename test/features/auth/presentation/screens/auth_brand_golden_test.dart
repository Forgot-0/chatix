import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/features/auth/presentation/screens/register_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pump_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Sign-in and sign-up open on the ChatiX mark rather than a stock icon.
///
/// Both screens live outside the app shell — nobody is signed in yet, so
/// there is no rail and no chat list — and the desktop goldens are the whole
/// window, as they are for the password-reset screens.
void main() {
  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = phone,
    bool dark = false,
  }) async {
    await tester.pumpWidgetBuilder(
      pumpableApp(
        overrides: [
          authRepositoryProvider.overrideWithValue(_MockAuthRepository()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: screen,
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
  }

  const screens = {'login': LoginScreen(), 'register': RegisterScreen()};

  for (final screen in screens.entries) {
    testWidgets('${screen.key} opens on the logo, not a stock icon', (
      tester,
    ) async {
      await pumpScreen(tester, screen.value);

      expect(find.byType(ChatixLogo), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
      expect(find.byIcon(Icons.person_add_alt), findsNothing);
    });
  }

  group('goldens', () {
    for (final screen in screens.entries) {
      for (final window in {'phone': phone, 'desktop': desktop}.entries) {
        for (final theme in {'light': false, 'dark': true}.entries) {
          testGoldens('${screen.key}, ${window.key}, ${theme.key}', (
            tester,
          ) async {
            await pumpScreen(
              tester,
              screen.value,
              size: window.value,
              dark: theme.value,
            );

            await screenMatchesGolden(
              tester,
              '${screen.key}_${window.key}_${theme.key}',
            );
          });
        }
      }
    }
  });
}
