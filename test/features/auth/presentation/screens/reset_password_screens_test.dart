import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/usecases/confirm_password_reset_use_case.dart';
import 'package:chatix/features/auth/domain/usecases/request_password_reset_use_case.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_confirm_screen.dart';
import 'package:chatix/features/auth/presentation/screens/reset_password_request_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class _MockRequestReset extends Mock implements RequestPasswordResetUseCase {}

class _MockConfirmReset extends Mock implements ConfirmPasswordResetUseCase {}

/// The two password-reset screens speak the reader's language: what they
/// ask for, what a field is missing, and why the server said no.
///
/// Both live outside the app shell — nobody is signed in yet — so the
/// desktop goldens are the whole window, not a pane beside a rail.
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  const phone = Size(390, 844);
  const desktop = Size(1440, 900);

  late _MockRequestReset requestReset;
  late _MockConfirmReset confirmReset;

  setUp(() {
    requestReset = _MockRequestReset();
    confirmReset = _MockConfirmReset();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    Size size = phone,
    bool dark = false,
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          requestPasswordResetUseCaseProvider.overrideWithValue(requestReset),
          confirmPasswordResetUseCaseProvider.overrideWithValue(confirmReset),
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

  group('asking for a code', () {
    testWidgets('explains itself and checks the address in Russian', (
      tester,
    ) async {
      await pumpScreen(tester, const ResetPasswordRequestScreen());

      expect(
        find.text(
          'Введите email вашего аккаунта — мы пришлём код для сброса пароля.',
        ),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Отправить код'));
      await tester.pumpAndSettle();

      expect(find.text('Введите корректный email'), findsOneWidget);
      verifyNever(() => requestReset.execute(email: any(named: 'email')));
    });

    testWidgets('a 429 is "too many attempts", in Russian', (tester) async {
      when(
        () => requestReset.execute(email: any(named: 'email')),
      ).thenAnswer((_) async => const Left(RateLimitFailure()));
      await pumpScreen(tester, const ResetPasswordRequestScreen());

      await tester.enterText(find.byType(TextField), 'ada@example.com');
      await tester.tap(find.text('Отправить код'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Слишком много попыток. Подождите минуту и попробуйте снова.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Too many'), findsNothing);
    });

    testWidgets('any other refusal is not the server\'s English', (
      tester,
    ) async {
      when(() => requestReset.execute(email: any(named: 'email'))).thenAnswer(
        (_) async => const Left(ServerFailure(message: 'Internal error')),
      );
      await pumpScreen(tester, const ResetPasswordRequestScreen());

      await tester.enterText(find.byType(TextField), 'ada@example.com');
      await tester.tap(find.text('Отправить код'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Internal error'), findsNothing);
    });
  });

  group('setting the new password', () {
    testWidgets('explains itself and checks every field in Russian', (
      tester,
    ) async {
      await pumpScreen(tester, const ResetPasswordConfirmScreen());

      expect(
        find.text('Введите код из письма и новый пароль.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField).at(1), 'short');
      await tester.enterText(find.byType(TextField).at(2), 'other');
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text('Обязательное поле'), findsOneWidget);
      expect(find.text('Минимум 8 символов'), findsOneWidget);
      expect(find.text('Пароли не совпадают'), findsOneWidget);
    });

    testWidgets('a refusal is said in Russian, not the server\'s words', (
      tester,
    ) async {
      when(
        () => confirmReset.execute(
          token: any(named: 'token'),
          password: any(named: 'password'),
          passwordRepeat: any(named: 'passwordRepeat'),
        ),
      ).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'INVALID_TOKEN',
            message: 'Invalid token',
            detail: {},
            status: 400,
          ),
        ),
      );
      await pumpScreen(tester, const ResetPasswordConfirmScreen());

      await tester.enterText(find.byType(TextField).at(0), '123456');
      await tester.enterText(find.byType(TextField).at(1), 'Secret1!');
      await tester.enterText(find.byType(TextField).at(2), 'Secret1!');
      final submit = find.byType(FilledButton);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Invalid token'), findsNothing);
    });
  });

  group('goldens', () {
    final windows = {'phone': phone, 'desktop': desktop};
    final screens = <String, Widget>{
      'reset_request': const ResetPasswordRequestScreen(),
      'reset_confirm': const ResetPasswordConfirmScreen(),
    };

    for (final screen in screens.entries) {
      for (final window in windows.entries) {
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

            // Submitted empty: the field errors are part of what changed.
            final submit = find.byType(FilledButton);
            await tester.ensureVisible(submit);
            await tester.tap(submit);
            await tester.pumpAndSettle();

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
