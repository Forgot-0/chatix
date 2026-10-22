import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/domain/usecases/get_oauth_url_use_case.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_buttons.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_provider_marks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

class _MockGetOAuthUrl extends Mock implements GetOAuthUrlUseCase {}

/// The OAuth section: "or", then one full-width button per provider
/// (api-docs §3.8) — or nothing at all. Each button keeps the colours,
/// stroke, mark and (for Yandex) words its provider requires.
void main() {
  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations ru = AppLocalizationsRu();

  late _MockGetOAuthUrl getUrl;

  setUp(() => getUrl = _MockGetOAuthUrl());

  Future<void> pumpSection(
    WidgetTester tester, {
    List<OAuthProvider>? providers,
    Locale locale = const Locale('en'),
    bool dark = false,
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
          theme: dark ? AppTheme.dark() : AppTheme.light(),
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

  Finder buttonFor(OAuthProvider provider) => find.byWidgetPredicate(
    (widget) => widget is OAuthButton && widget.provider == provider,
  );

  Material materialOf(WidgetTester tester, OAuthProvider provider) =>
      tester.widget<Material>(
        find
            .descendant(
              of: buttonFor(provider),
              matching: find.byType(Material),
            )
            .first,
      );

  // The provider's redirect lands on the backend, which has no way yet to
  // hand the session back to the app; a button now would be a dead end.
  testWidgets('the shipped build offers no provider', (tester) async {
    await pumpSection(tester);

    expect(find.byType(OAuthButton), findsNothing);
    expect(find.text(en.authDividerOr), findsNothing);
  });

  testWidgets('each provider gets a full-width pill under "or"', (
    tester,
  ) async {
    await pumpSection(tester, providers: OAuthProvider.values);

    expect(find.text(en.authDividerOr), findsOneWidget);
    for (final provider in OAuthProvider.values) {
      final size = tester.getSize(buttonFor(provider));
      expect(size.width, 420, reason: provider.name);
      expect(size.height, OAuthButtonSpec.height, reason: provider.name);
      expect(
        materialOf(tester, provider).shape,
        isA<StadiumBorder>(),
        reason: provider.name,
      );
    }
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with Yandex ID'), findsOneWidget);
    expect(find.text('Sign in with GitHub'), findsOneWidget);
  });

  group('Yandex keeps its own words and mark', () {
    testWidgets('in Russian: «Войти с Яндекс ID» and the Я', (tester) async {
      await pumpSection(
        tester,
        providers: const [OAuthProvider.yandex],
        locale: const Locale('ru'),
      );

      expect(find.text(ru.oauthYandexSignIn), findsOneWidget);
      expect(ru.oauthYandexSignIn, 'Войти с Яндекс ID');
      expect(
        tester.widget<YandexMark>(find.byType(YandexMark)).cyrillic,
        isTrue,
      );
    });

    testWidgets('elsewhere: the English button and the Y', (tester) async {
      await pumpSection(
        tester,
        providers: const [OAuthProvider.yandex],
        locale: const Locale('de'),
      );

      expect(find.text('Sign in with Yandex ID'), findsOneWidget);
      expect(
        tester.widget<YandexMark>(find.byType(YandexMark)).cyrillic,
        isFalse,
      );
    });
  });

  group('each provider in its own colours', () {
    testWidgets('light: white buttons, Yandex outlined in black', (
      tester,
    ) async {
      await pumpSection(tester, providers: OAuthProvider.values);

      final google = materialOf(tester, OAuthProvider.google);
      expect(google.color, OAuthButtonSpec.lightFill);
      expect(
        (google.shape! as StadiumBorder).side,
        const BorderSide(color: OAuthButtonSpec.lightStroke),
      );

      final yandex = materialOf(tester, OAuthProvider.yandex);
      expect(yandex.color, OAuthButtonSpec.yandexPaper);
      final stroke = (yandex.shape! as StadiumBorder).side;
      expect(stroke.color, OAuthButtonSpec.yandexInk);
      expect(stroke.width, 2);

      expect(tester.widget<GoogleMark>(find.byType(GoogleMark)).dark, isFalse);
      expect(tester.widget<GitHubMark>(find.byType(GitHubMark)).dark, isFalse);
    });

    testWidgets('dark: Google\'s dark button, Yandex\'s black one', (
      tester,
    ) async {
      await pumpSection(tester, providers: OAuthProvider.values, dark: true);

      expect(
        materialOf(tester, OAuthProvider.google).color,
        OAuthButtonSpec.darkFill,
      );
      final yandex = materialOf(tester, OAuthProvider.yandex);
      expect(yandex.color, OAuthButtonSpec.yandexInk);
      expect((yandex.shape! as StadiumBorder).side, BorderSide.none);
      expect(tester.widget<GoogleMark>(find.byType(GoogleMark)).dark, isTrue);
      expect(tester.widget<GitHubMark>(find.byType(GitHubMark)).dark, isTrue);
    });
  });

  testWidgets('a screen reader hears the button, not the logo', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSection(tester, providers: const [OAuthProvider.google]);

    expect(
      tester.getSemantics(buttonFor(OAuthProvider.google)),
      matchesSemantics(
        label: 'Sign in with Google',
        isButton: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a refusal is said in the reader\'s words', (tester) async {
    when(
      () => getUrl.execute(provider: any(named: 'provider')),
    ).thenAnswer((_) async => const Left(RateLimitFailure()));
    await pumpSection(tester, providers: const [OAuthProvider.github]);

    await tester.tap(find.byType(OAuthButton));
    await tester.pumpAndSettle();

    verify(() => getUrl.execute(provider: 'github')).called(1);
    expect(find.text(en.authErrorTooManyAttempts), findsOneWidget);
  });

  test('the provider ids are the ones the backend accepts', () {
    expect(
      OAuthProvider.values.map((provider) => provider.id).toSet(),
      GetOAuthUrlUseCase.supportedProviders,
    );
  });

  // The files are the providers' own, at every density Flutter may ask
  // for; a missing one would quietly fall back to a blurry neighbour.
  testWidgets('every mark file is in the bundle', (tester) async {
    final files = [
      OAuthMarkAssets.googleLight,
      OAuthMarkAssets.googleDark,
      for (final density in ['2.0x', '3.0x', '4.0x']) ...[
        OAuthMarkAssets.googleLight.replaceFirst('oauth/', 'oauth/$density/'),
        OAuthMarkAssets.googleDark.replaceFirst('oauth/', 'oauth/$density/'),
      ],
      OAuthMarkAssets.githubBlack,
      OAuthMarkAssets.githubWhite,
    ];

    for (final file in files) {
      final bytes = await rootBundle.load(file);
      expect(bytes.lengthInBytes, greaterThan(0), reason: file);
    }
  });

  group('parseSvgPathData', () {
    test('draws both Yandex letters inside their 44 px disc', () {
      for (final glyph in [
        YandexMarkPainter.cyrillicGlyph,
        YandexMarkPainter.latinGlyph,
      ]) {
        final bounds = parseSvgPathData(glyph).getBounds();
        expect(bounds.left, greaterThan(8));
        expect(bounds.top, greaterThan(8));
        expect(bounds.right, lessThan(36));
        expect(bounds.bottom, lessThan(37));
      }
    });

    test('reads every command it claims to', () {
      final path = parseSvgPathData('M0 0L10 0H20V10C20 20 10 20 0 20Z');
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 20, 20));
      expect(path.contains(const Offset(10, 10)), isTrue);
    });

    test('repeats a command for further coordinates', () {
      final path = parseSvgPathData('M0 0 10 0 10 10Z');
      expect(path.getBounds(), const Rect.fromLTRB(0, 0, 10, 10));
    });

    test('refuses what it cannot draw faithfully', () {
      expect(() => parseSvgPathData('M0 0l10 10'), throwsFormatException);
      expect(
        () => parseSvgPathData('M0 0A5 5 0 0 1 10 10'),
        throwsFormatException,
      );
      expect(() => parseSvgPathData('10 10'), throwsFormatException);
      expect(() => parseSvgPathData('M0'), throwsFormatException);
    });
  });
}
