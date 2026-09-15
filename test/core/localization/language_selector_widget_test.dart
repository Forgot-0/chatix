import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/localization/language_selector_widget.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/features/settings/presentation/screens/language_settings_screen.dart';
import 'package:chatix/l10n/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget home, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'the language list scrolls instead of overflowing a short screen',
    (tester) async {
      // Shorter than the six locales need: the list used to be laid out at its
      // natural height inside an Expanded and blew the Column by ~45px.
      await pump(tester, const LanguageSettingsScreen(), const Size(400, 500));

      expect(tester.takeException(), isNull);

      final list = find.descendant(
        of: find.byType(LanguageSelectorWidget),
        matching: find.byType(Scrollable),
      );
      expect(list, findsOneWidget);

      await tester.drag(list, const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a tall screen still lays the list out at its natural height', (
    tester,
  ) async {
    await pump(tester, const LanguageSettingsScreen(), const Size(400, 1400));

    expect(tester.takeException(), isNull);
    for (final locale in AppLocalizations.supportedLocales) {
      expect(find.text(locale.languageCode.toUpperCase()), findsWidgets);
    }
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
