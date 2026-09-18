import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/screens/register_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

import '../../../../helpers/pump_app.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// `DUPLICATE_USER` names the field it means — `{field, value}`, api-docs
/// §2.4 — so the screen puts it on that field rather than in a banner.
void main() {
  final AppLocalizations l10n = AppLocalizationsEn();

  late _MockAuthRepository repository;

  setUp(() => repository = _MockAuthRepository());

  Future<void> pumpRegister(WidgetTester tester) async {
    // Four fields, a meter and two buttons do not fit the default 800x600
    // test surface, and a button below the fold cannot be tapped.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      pumpableApp(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'adalovelace');
    await tester.enterText(fields.at(1), 'ada@example.com');
    await tester.enterText(fields.at(2), 'Str0ng!pass');
    await tester.enterText(fields.at(3), 'Str0ng!pass');

    await tester.tap(find.widgetWithText(FilledButton, l10n.register));
    await tester.pumpAndSettle();
  }

  void failRegisterWith(Failure failure) {
    when(
      () => repository.register(
        username: any(named: 'username'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        passwordRepeat: any(named: 'passwordRepeat'),
      ),
    ).thenAnswer((_) async => Left(failure));
  }

  testWidgets('a taken username is said on the username field', (tester) async {
    failRegisterWith(
      const ApiFailure(
        code: 'DUPLICATE_USER',
        message: 'taken',
        detail: {'field': 'username', 'value': 'adalovelace'},
        status: 409,
      ),
    );

    await pumpRegister(tester);
    await fillAndSubmit(tester);

    expect(find.text(l10n.authErrorDuplicateUsername), findsOneWidget);
    expect(find.text(l10n.authErrorDuplicateEmail), findsNothing);
  });

  testWidgets('a taken email is said on the email field', (tester) async {
    failRegisterWith(
      const ApiFailure(
        code: 'DUPLICATE_USER',
        message: 'taken',
        detail: {'field': 'email', 'value': 'ada@example.com'},
        status: 409,
      ),
    );

    await pumpRegister(tester);
    await fillAndSubmit(tester);

    expect(find.text(l10n.authErrorDuplicateEmail), findsOneWidget);
  });

  testWidgets('editing the blamed field clears the server error', (
    tester,
  ) async {
    failRegisterWith(
      const ApiFailure(
        code: 'DUPLICATE_USER',
        message: 'taken',
        detail: {'field': 'username', 'value': 'adalovelace'},
        status: 409,
      ),
    );

    await pumpRegister(tester);
    await fillAndSubmit(tester);
    expect(find.text(l10n.authErrorDuplicateUsername), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'adalovelace2');
    await tester.pumpAndSettle();

    expect(find.text(l10n.authErrorDuplicateUsername), findsNothing);
  });

  testWidgets('a rate-limited registration explains itself in the banner', (
    tester,
  ) async {
    failRegisterWith(const RateLimitFailure());

    await pumpRegister(tester);
    await fillAndSubmit(tester);

    expect(find.text(l10n.authErrorTooManyAttempts), findsOneWidget);
  });

  testWidgets('the password meter grades what is typed', (tester) async {
    when(
      () => repository.register(
        username: any(named: 'username'),
        email: any(named: 'email'),
        password: any(named: 'password'),
        passwordRepeat: any(named: 'passwordRepeat'),
      ),
    ).thenAnswer(
      (_) async => const Right(
        UserEntity(id: 1, username: 'ada', email: 'ada@example.com'),
      ),
    );

    await pumpRegister(tester);

    expect(find.text(l10n.passwordStrengthLabel), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'short');
    await tester.pumpAndSettle();
    expect(find.text(l10n.passwordStrengthWeak), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(2), 'Str0ng!password');
    await tester.pumpAndSettle();
    expect(find.text(l10n.passwordStrengthGood), findsOneWidget);
  });
}
