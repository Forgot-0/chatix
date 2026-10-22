import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/usecases/get_oauth_url_use_case.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_buttons.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

class _MockGetOAuthUrl extends Mock implements GetOAuthUrlUseCase {}

/// The OAuth section: "or", then one full-width button per provider
/// (api-docs §3.8) — or nothing at all.
void main() {
  late _MockGetOAuthUrl getUrl;

  setUp(() => getUrl = _MockGetOAuthUrl());

  Future<void> pumpSection(
    WidgetTester tester, {
    List<OAuthProvider>? providers,
    Locale locale = const Locale('en'),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          getOAuthUrlUseCaseProvider.overrideWithValue(getUrl),
          if (providers != null)
            oauthProvidersProvider.overrideWithValue(providers),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Center(child: SizedBox(width: 420, child: OAuthSection())),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // The provider's redirect lands on the backend, which has no way yet to
  // hand the session back to the app; a button now would be a dead end.
  testWidgets('the shipped build offers no provider', (tester) async {
    await pumpSection(tester);

    expect(find.byType(OAuthButton), findsNothing);
    expect(find.text(AppLocalizationsEn().authDividerOr), findsNothing);
  });

  testWidgets('each provider gets a full-width button under "or"', (
    tester,
  ) async {
    final l10n = AppLocalizationsEn();
    await pumpSection(tester, providers: OAuthProvider.values);

    expect(find.text(l10n.authDividerOr), findsOneWidget);
    for (final name in ['Google', 'Yandex', 'GitHub']) {
      final button = find.widgetWithText(
        OutlinedButton,
        l10n.continueWith(name),
      );
      expect(button, findsOneWidget, reason: name);
      expect(tester.getSize(button).width, 420, reason: name);
    }
  });

  testWidgets('Yandex is written the Russian way in Russian', (tester) async {
    final l10n = AppLocalizationsRu();
    await pumpSection(
      tester,
      providers: const [OAuthProvider.yandex],
      locale: const Locale('ru'),
    );

    expect(find.text(l10n.continueWith('Яндекс')), findsOneWidget);
  });

  testWidgets('a refusal is said in the reader\'s words', (tester) async {
    when(
      () => getUrl.execute(provider: any(named: 'provider')),
    ).thenAnswer((_) async => const Left(RateLimitFailure()));
    await pumpSection(tester, providers: const [OAuthProvider.github]);

    await tester.tap(find.byType(OAuthButton));
    await tester.pumpAndSettle();

    verify(() => getUrl.execute(provider: 'github')).called(1);
    expect(
      find.text(AppLocalizationsEn().authErrorTooManyAttempts),
      findsOneWidget,
    );
  });

  test('the provider ids are the ones the backend accepts', () {
    expect(
      OAuthProvider.values.map((provider) => provider.id).toSet(),
      GetOAuthUrlUseCase.supportedProviders,
    );
  });
}
