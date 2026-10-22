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

    await tester.tap(find.widgetWithText(FilledButton, l10n.registerSubmit));
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

  testWidgets('the rules tick off as the password is typed', (tester) async {
    await pumpRegister(tester);

    int ticks() => find.byIcon(Icons.check_circle).evaluate().length;
    expect(find.text(l10n.passwordRuleUppercase), findsOneWidget);
    expect(ticks(), 0);

    await tester.enterText(find.byType(TextField).at(2), 'chatix');
    await tester.pumpAndSettle();
    expect(ticks(), 1);

    await tester.enterText(find.byType(TextField).at(2), 'Chatix2026!');
    await tester.pumpAndSettle();
    expect(ticks(), 5);
  });

  testWidgets('typing the password does not nag about the empty repeat', (
    tester,
  ) async {
    await pumpRegister(tester);

    await tester.enterText(find.byType(TextField).at(2), 'Str0ng!pass');
    await tester.pumpAndSettle();

    expect(find.text(l10n.validationPasswordRepeatRequired), findsNothing);

    // Once there is a repeat, it follows the password.
    await tester.enterText(find.byType(TextField).at(3), 'Str0ng!pass');
    await tester.enterText(find.byType(TextField).at(2), 'Str0ng!pas');
    await tester.pumpAndSettle();
    expect(find.text(l10n.validationPasswordsDoNotMatch), findsOneWidget);
  });

  testWidgets('PASSWORD_MISMATCH from the server lands on the repeat', (
    tester,
  ) async {
    failRegisterWith(
      const ApiFailure(
        code: 'PASSWORD_MISMATCH',
        message: 'Passwords do not match',
        detail: {},
        status: 400,
      ),
    );

    await pumpRegister(tester);
    await fillAndSubmit(tester);

    final repeat = tester.widget<TextField>(find.byType(TextField).at(3));
    expect(repeat.decoration?.errorText, l10n.authErrorPasswordMismatch);
  });

  testWidgets('Enter walks the form top to bottom and then submits', (
    tester,
  ) async {
    failRegisterWith(const NetworkFailure());
    await pumpRegister(tester);

    final fields = find.byType(TextField);
    final values = [
      'adalovelace',
      'ada@example.com',
      'Str0ng!pass',
      'Str0ng!pass',
    ];
    for (var i = 0; i < 4; i++) {
      final field = tester.widget<TextField>(fields.at(i));
      expect(
        field.textInputAction,
        i < 3 ? TextInputAction.next : TextInputAction.done,
        reason: 'field $i',
      );
      await tester.showKeyboard(fields.at(i));
      await tester.enterText(fields.at(i), values[i]);
      await tester.testTextInput.receiveAction(field.textInputAction!);
      await tester.pumpAndSettle();
      if (i < 3) {
        expect(
          tester.widget<TextField>(fields.at(i + 1)).focusNode?.hasFocus,
          isTrue,
          reason: 'Enter on field $i moves on',
        );
      }
    }

    verify(
      () => repository.register(
        username: 'adalovelace',
        email: 'ada@example.com',
        password: 'Str0ng!pass',
        passwordRepeat: 'Str0ng!pass',
      ),
    ).called(1);
  });

  testWidgets('the fields tell the password manager what they hold', (
    tester,
  ) async {
    await pumpRegister(tester);

    final hints = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.autofillHints)
        .toList();
    expect(hints, [
      [AutofillHints.newUsername],
      [AutofillHints.email],
      [AutofillHints.newPassword],
      [AutofillHints.newPassword],
    ]);
  });
}
