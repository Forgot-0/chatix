import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/settings/dev_menu.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/websocket/socket_protocol_log.dart';
import 'package:chatix/features/settings/presentation/providers/about_providers.dart';
import 'package:chatix/features/settings/presentation/screens/about_screen.dart';
import 'package:chatix/features/settings/presentation/screens/developer_menu_screen.dart';
import 'package:chatix/features/settings/presentation/widgets/whats_new_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/settings_harness.dart';

/// About — the version, what is new, the links — and the developer menu
/// seven taps on that version open.
void main() {
  final ru = AppLocalizationsRu();

  Finder row(String title) => find.widgetWithText(AppGroupedTile, title);

  Future<SettingsHarness> pumpAbout(
    WidgetTester tester, {
    bool developer = false,
    Map<AboutLink, Uri> links = const {},
  }) async {
    final harness = SettingsHarness(
      developer: developer,
      links: links,
      version: const AppVersion(version: '1.4.2', build: '58'),
      screens: const {AboutSettingsRoute.location: AboutScreen()},
    );
    await harness.pump(tester, initialLocation: AboutSettingsRoute.location);
    return harness;
  }

  /// Taps the version [times] times, a frame apart.
  Future<void> tapVersion(WidgetTester tester, int times) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(row(ru.aboutVersion));
      await tester.pump();
    }
  }

  group('About', () {
    testWidgets('names the build the platform says is installed', (
      tester,
    ) async {
      await pumpAbout(tester);

      expect(
        find.descendant(
          of: row(ru.aboutVersion),
          matching: find.text(ru.aboutVersionValue('1.4.2', '58')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('only the links this build was configured with', (
      tester,
    ) async {
      await pumpAbout(
        tester,
        links: {AboutLink.privacyPolicy: Uri.parse('https://example.org/p')},
      );

      expect(row(ru.aboutPrivacyPolicy), findsOneWidget);
      expect(row(ru.aboutTerms), findsNothing);
      expect(row(ru.aboutSupport), findsNothing);
      // The licences are the app's own, so they are always there.
      expect(row(ru.aboutLicenses), findsOneWidget);
    });

    testWidgets('"What\'s new" opens this version\'s notes', (tester) async {
      await pumpAbout(tester);

      await tester.tap(row(ru.aboutWhatsNew));
      await tester.pumpAndSettle();

      expect(find.text(ru.aboutWhatsNewTitle('1.4.2')), findsOneWidget);
      for (final note in whatsNewNotes(ru)) {
        expect(find.text(note.title), findsOneWidget);
        expect(find.text(note.body), findsOneWidget);
      }

      await tester.tap(find.text(ru.close));
      await tester.pumpAndSettle();
      expect(find.text(ru.aboutWhatsNewTitle('1.4.2')), findsNothing);
    });

    testWidgets('seven taps on the version open the developer menu', (
      tester,
    ) async {
      final harness = await pumpAbout(tester);

      // Quiet for the first few: somebody reading the version is not
      // looking for a secret.
      await tapVersion(tester, 2);
      expect(find.textContaining(ru.devMenuTapsLeft(5)), findsNothing);

      await tapVersion(tester, 1);
      expect(find.text(ru.devMenuTapsLeft(4)), findsOneWidget);
      await tapVersion(tester, 3);
      expect(find.text(ru.devMenuTapsLeft(1)), findsOneWidget);
      expect(harness.container.read(devMenuUnlockedProvider), isFalse);

      await tapVersion(tester, 1);
      expect(harness.container.read(devMenuUnlockedProvider), isTrue);
      expect(find.text(ru.devMenuUnlocked), findsOneWidget);

      // And it says so, rather than counting again, once it is open. (The
      // toast before it has to make way first.)
      await tapVersion(tester, 1);
      await tester.pumpAndSettle();
      expect(find.text(ru.devMenuAlreadyOpen), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('the developer menu', () {
    Future<SettingsHarness> pumpMenu(WidgetTester tester) async {
      final harness = SettingsHarness(
        developer: true,
        screens: const {DeveloperSettingsRoute.location: DeveloperMenuScreen()},
      );
      await harness.pump(
        tester,
        initialLocation: DeveloperSettingsRoute.location,
      );
      return harness;
    }

    testWidgets('records frames for this run when asked to', (tester) async {
      final harness = await pumpMenu(tester);
      final copy = row(ru.wsDiagnostics);

      // Nothing recorded, nothing to copy.
      expect(tester.widget<AppGroupedTile>(copy).enabled, isFalse);

      await tester.tap(
        find.widgetWithText(AppGroupedSwitchTile, ru.devMenuRecordSocket),
      );
      await tester.pumpAndSettle();

      expect(harness.container.read(socketRecordingSwitchProvider), isTrue);
      expect(tester.widget<AppGroupedTile>(copy).enabled, isTrue);
      expect(
        find.text(ru.wsDiagnosticsFrames(0)),
        findsOneWidget,
        reason: 'the log is the shared one, empty until a socket writes',
      );
      expect(harness.container.read(socketProtocolLogProvider).length, 0);
    });

    testWidgets('opens the design system', (tester) async {
      await pumpMenu(tester);

      await tester.tap(row(ru.designSystem));
      await tester.pumpAndSettle();
      expect(
        find.text(settingsStubLabel(ComponentShowcaseRoute.location)),
        findsOneWidget,
      );
    });

    testWidgets('hiding it puts it away and stops the recording', (
      tester,
    ) async {
      final harness = await pumpMenu(tester);
      harness.container.read(socketRecordingSwitchProvider.notifier).set(true);
      await tester.pumpAndSettle();

      await tester.tap(row(ru.devMenuHide));
      await tester.pumpAndSettle();

      expect(harness.container.read(devMenuUnlockedProvider), isFalse);
      expect(harness.container.read(socketRecordingSwitchProvider), isFalse);
      // Back on the list, which no longer has the row.
      expect(row(ru.devMenuTitle), findsNothing);
      expect(row(ru.aboutTitle), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });
}
