import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/localization/language_selector_widget.dart';
import 'package:chatix/core/providers/localization_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart' as arb;
import 'package:chatix/l10n/app_localizations_delegate.dart';
import 'package:chatix/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget home,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        // The app's own wiring: the screen follows the chosen locale.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(persistentLocaleProvider),
            localizationsDelegates: [
              ...AppLocalizations.localizationsDelegates,
              arb.AppLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: home,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('every language under its own name, Russian included', (
    tester,
  ) async {
    await pump(tester, const LanguageSettingsScreen(), const Size(400, 1400));

    expect(tester.takeException(), isNull);
    expect(AppLocalizations.supportedLocales, contains(const Locale('ru')));
    for (final locale in AppLocalizations.supportedLocales) {
      expect(
        find.text(LocalizationUtils.getLocaleName(locale)),
        findsOneWidget,
      );
    }
    expect(find.text('Русский'), findsOneWidget);
  });

  testWidgets('picking one switches the app to it, ticked', (tester) async {
    final container = await pump(
      tester,
      const LanguageSettingsScreen(),
      const Size(400, 1400),
    );

    await tester.tap(find.text('Русский'));
    await tester.pumpAndSettle();

    expect(container.read(persistentLocaleProvider), const Locale('ru'));
    // The screen itself is now in Russian, and says which one is on.
    expect(find.text('Язык'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('a short screen scrolls rather than overflowing', (tester) async {
    await pump(tester, const LanguageSettingsScreen(), const Size(400, 360));

    await tester.drag(find.byType(Scrollable).last, const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dialog keeps the list inside the viewport', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => LanguageSelectorDialog.show(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      const Size(400, 560),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageSelectorWidget), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
