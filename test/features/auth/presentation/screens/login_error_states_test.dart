import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

import '../../../../helpers/pump_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// What each `/auth/login/` failure looks like to the person in front of it
/// (api-docs §2.4, §0.7).
void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  late _MockAuthRepository repository;

  setUp(() {
    repository = _MockAuthRepository();
    when(
      () => repository.requestEmailVerification(email: any(named: 'email')),
    ).thenAnswer((_) async => const Left(RateLimitFailure()));
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      pumpableApp(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> signIn(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).first, 'ada@example.com');
    await tester.enterText(find.byType(TextField).last, 'Str0ng!pass');
    await tester.tap(find.text(l10n.logIn));
    await tester.pumpAndSettle();
  }

  void failLoginWith(Failure failure) {
    when(
      () => repository.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Left(failure));
  }

  testWidgets('WRONG_LOGIN_DATA is said plainly, in the form', (tester) async {
    failLoginWith(
      const ApiFailure(
        code: 'WRONG_LOGIN_DATA',
        message: 'Incorrect username or password',
        detail: {'username': 'ada@example.com'},
        status: 400,
      ),
    );

    await pumpLogin(tester);
    await signIn(tester);

    expect(find.text(l10n.authErrorWrongLoginData), findsOneWidget);
    // Nothing to do about it but retype, so no action is offered.
    expect(find.text(l10n.authResendEmail), findsNothing);
  });

  testWidgets('EMAIL_NOT_CONFIRMED comes with a way out of it', (tester) async {
    failLoginWith(
      const ApiFailure(
        code: 'EMAIL_NOT_CONFIRMED',
        message: 'confirm your email',
        detail: {'email': 'ada@example.com'},
        status: 403,
      ),
    );

    await pumpLogin(tester);
    await signIn(tester);

    expect(
      find.text(l10n.authErrorEmailNotConfirmedFor('ada@example.com')),
      findsOneWidget,
    );

    final resend = find.text(l10n.authResendEmail);
    expect(resend, findsOneWidget);

    await tester.tap(resend);
    await tester.pumpAndSettle();

    // The address came from the error detail, not from the login field.
    verify(
      () => repository.requestEmailVerification(email: 'ada@example.com'),
    ).called(1);
  });

  // 429 arrives as a bare {"detail": ...} with no error code to read
  // (api-docs §0.7), so it has to be its own branch all the way up.
  testWidgets('a rate limit says so instead of blaming the password', (
    tester,
  ) async {
    failLoginWith(const RateLimitFailure(message: 'Too Many Requests'));

    await pumpLogin(tester);
    await signIn(tester);

    expect(find.text(l10n.authErrorTooManyAttempts), findsOneWidget);
    expect(find.text(l10n.authErrorWrongLoginData), findsNothing);
  });

  testWidgets('a dead network is not a rejected password', (tester) async {
    failLoginWith(const NetworkFailure());

    await pumpLogin(tester);
    await signIn(tester);

    expect(find.text(l10n.authErrorOffline), findsOneWidget);
  });

  testWidgets('the password can be revealed and hidden again', (tester) async {
    await pumpLogin(tester);

    expect(find.byTooltip(l10n.passwordShow), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.passwordShow));
    await tester.pumpAndSettle();

    expect(find.byTooltip(l10n.passwordHide), findsOneWidget);
  });
}
