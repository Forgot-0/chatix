import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/router/settings_pane_shell.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';
import 'package:chatix/features/settings/presentation/widgets/settings_profile_card.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/pane_frame.dart';
import '../../helpers/settings_harness.dart';

/// The settings list: the card on top, the coloured groups, search, signing
/// out — and, in a two-pane window, the list beside the section it opened.
void main() {
  final ru = AppLocalizationsRu();

  Finder row(String title) => find.widgetWithText(AppGroupedTile, title);

  Future<void> tapRow(WidgetTester tester, String title) async {
    await tester.ensureVisible(row(title));
    await tester.pumpAndSettle();
    await tester.tap(row(title));
    await tester.pumpAndSettle();
  }

  group('the profile card', () {
    testWidgets('shows the name, the handle and the way to edit', (
      tester,
    ) async {
      await SettingsHarness().pump(tester);

      final card = find.byType(SettingsProfileCard);
      expect(
        find.descendant(of: card, matching: find.text('Мария Иванова')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('@maria')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text(ru.profileEditAction)),
        findsOneWidget,
      );
      expect(find.byTooltip(ru.changePhoto), findsOneWidget);
    });

    testWidgets('stands on the account until the profile arrives', (
      tester,
    ) async {
      final pending = PendingProfile();
      await SettingsHarness(profileFuture: pending.future).pump(tester);

      final card = find.byType(SettingsProfileCard);
      // The handle is known from sign-in; the name is not yet.
      expect(
        find.descendant(of: card, matching: find.text('@maria')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('maria@example.com')),
        findsOneWidget,
      );
      // Nothing to upload a photo to before there is a profile to put it on.
      expect(find.byTooltip(ru.changePhoto), findsNothing);

      pending.complete();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: card, matching: find.text('Мария Иванова')),
        findsOneWidget,
      );
    });

    testWidgets('a profile with no name shows the handle and the email', (
      tester,
    ) async {
      await SettingsHarness(
        profile: kSettingsProfile.copyWith(displayName: '  '),
      ).pump(tester);

      final card = find.byType(SettingsProfileCard);
      expect(
        find.descendant(of: card, matching: find.text('@maria')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: card, matching: find.text('maria@example.com')),
        findsOneWidget,
      );
    });

    testWidgets('a tap opens the profile, "Edit" opens the form', (
      tester,
    ) async {
      final harness = SettingsHarness();
      await harness.pump(tester);

      await tester.tap(find.text('Мария Иванова'));
      await tester.pumpAndSettle();
      expect(find.text(settingsStubLabel(ProfileRoute.location)), findsOne);

      harness.router.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text(ru.profileEditAction));
      await tester.pumpAndSettle();
      expect(find.text(settingsStubLabel(ProfileEditRoute.location)), findsOne);
    });
  });

  group('the rows', () {
    testWidgets('every section, in its groups, each on its own colour', (
      tester,
    ) async {
      await SettingsHarness().pump(tester, surface: const Size(390, 1400));

      final titles = [
        ru.notifications,
        ru.notificationsAndSounds,
        ru.privacySettingsTitle,
        ru.dataStorageTitle,
        ru.privacyDevices,
        ru.appearanceTitle,
        ru.settingsChatFolders,
        ru.language,
        ru.aboutTitle,
      ];
      for (final title in titles) {
        expect(row(title), findsOneWidget, reason: title);
      }
      // Top to bottom in that order.
      final tops = [
        for (final title in titles) tester.getTopLeft(row(title)).dy,
      ];
      expect(tops, [...tops]..sort());

      // Four groups and the sign-out card on its own.
      expect(find.byType(AppGroupedSection), findsNWidgets(1 + 4 + 1));

      final plates = tester
          .widgetList<AppIconPlate>(find.byType(AppIconPlate))
          .map((plate) => plate.color)
          .toList();
      // One colour per row, signing out included.
      expect(plates.toSet().length, plates.length);
    });

    testWidgets('the developer row waits for seven taps on the version', (
      tester,
    ) async {
      await SettingsHarness().pump(tester, surface: const Size(390, 1400));
      expect(row(ru.devMenuTitle), findsNothing);
    });

    testWidgets('once open, the developer row sits under About', (
      tester,
    ) async {
      await SettingsHarness(
        developer: true,
      ).pump(tester, surface: const Size(390, 1400));

      expect(row(ru.devMenuTitle), findsOneWidget);
      expect(
        tester.getTopLeft(row(ru.devMenuTitle)).dy,
        greaterThan(tester.getTopLeft(row(ru.aboutTitle)).dy),
      );
    });

    testWidgets('the language row says which language is on screen', (
      tester,
    ) async {
      await SettingsHarness().pump(tester);

      expect(
        find.descendant(of: row(ru.language), matching: find.text('Русский')),
        findsOneWidget,
      );
    });

    testWidgets('the alerts row carries the unread count, read out in words', (
      tester,
    ) async {
      await SettingsHarness(alerts: 5).pump(tester);

      final alerts = row(ru.notifications);
      expect(
        find.descendant(of: alerts, matching: find.text('5')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: alerts,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == ru.unreadNotificationsCount(5),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('nothing unread, no badge', (tester) async {
      await SettingsHarness().pump(tester);

      expect(
        find.descendant(
          of: row(ru.notifications),
          matching: find.byType(Badge),
        ),
        findsNothing,
      );
    });

    testWidgets('on a phone a row pushes its section', (tester) async {
      final harness = SettingsHarness();
      await harness.pump(tester);

      await tapRow(tester, ru.dataStorageTitle);

      expect(
        find.text(settingsStubLabel(DataStorageSettingsRoute.location)),
        findsOneWidget,
      );
      // With the list under it, and a way back to it.
      expect(find.byType(BackButton), findsOneWidget);
      harness.router.pop();
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('the alerts list opens over everything, not as a section', (
      tester,
    ) async {
      await SettingsHarness().pump(tester);

      await tapRow(tester, ru.notifications);

      expect(
        find.text(settingsStubLabel(NotificationsRoute.location)),
        findsOneWidget,
      );
      expect(find.byType(SettingsScreen), findsNothing);
    });
  });

  group('signing out', () {
    testWidgets('asks first, on its own red row at the bottom', (tester) async {
      await SettingsHarness().pump(tester, surface: const Size(390, 1400));

      final signOut = row(ru.logout);
      expect(tester.widget<AppGroupedTile>(signOut).destructive, isTrue);
      expect(
        tester.getTopLeft(signOut).dy,
        greaterThan(tester.getTopLeft(row(ru.aboutTitle)).dy),
      );

      await tester.tap(signOut);
      await tester.pumpAndSettle();
      expect(find.text(ru.logoutConfirmTitle), findsOneWidget);

      await tester.tap(find.text(ru.cancel));
      await tester.pumpAndSettle();
      expect(find.text(ru.logoutConfirmTitle), findsNothing);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });
  });

  group('search', () {
    testWidgets('narrows the list to matching names, rows with their section', (
      tester,
    ) async {
      await SettingsHarness().pump(tester);

      await tester.enterText(find.byType(TextField), 'кэш');
      await tester.pumpAndSettle();

      // The card and the groups give way to the hits.
      expect(find.byType(SettingsProfileCard), findsNothing);
      expect(find.text(ru.dataStorageCacheTitle), findsOneWidget);
      expect(find.text(ru.cacheLimit), findsOneWidget);
      // Each says where it lives.
      expect(find.text(ru.dataStorageTitle), findsNWidgets(2));

      await tester.tap(find.text(ru.cacheLimit));
      await tester.pumpAndSettle();
      expect(
        find.text(settingsStubLabel(DataStorageSettingsRoute.location)),
        findsOneWidget,
      );
    });

    testWidgets('a section by its own name comes first', (tester) async {
      await SettingsHarness().pump(tester);

      await tester.enterText(find.byType(TextField), 'оформ');
      await tester.pumpAndSettle();

      expect(find.text(ru.appearanceTitle), findsOneWidget);
    });

    testWidgets('says so when nothing matches, and clears back to the list', (
      tester,
    ) async {
      await SettingsHarness().pump(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(ru.settingsSearchEmpty('zzz')), findsOneWidget);

      await tester.tap(find.byTooltip(ru.settingsSearchClear));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsProfileCard), findsOneWidget);
    });
  });

  group('wide windows', () {
    testWidgets('one wide pane keeps the list to a readable column', (
      tester,
    ) async {
      await SettingsHarness().pump(tester, window: PaneWindow.tablet);

      final column = tester.getRect(find.byType(ListView));
      expect(column.width, AppContentWidths.form);
      final pane = tester.getRect(find.byType(AppContentWidth));
      expect(column.center.dx, closeTo(pane.center.dx, 0.5));
    });

    testWidgets('two panes: the list on the left, a placeholder beside it', (
      tester,
    ) async {
      await SettingsHarness().pump(tester, window: PaneWindow.desktop);

      final list = tester.getRect(find.byType(SettingsScreen));
      expect(list.width, 360);
      expect(find.byType(SettingsPlaceholderPane), findsOneWidget);
      expect(find.text(ru.settingsPanePlaceholderTitle), findsOneWidget);
    });

    testWidgets(
      'two panes: a row swaps the section beside the list and stays marked',
      (tester) async {
        final harness = SettingsHarness();
        await harness.pump(tester, window: PaneWindow.desktop);

        await tapRow(tester, ru.appearanceTitle);
        expect(
          find.text(settingsStubLabel(AppearanceSettingsRoute.location)),
          findsOneWidget,
        );
        expect(
          tester.widget<AppGroupedTile>(row(ru.appearanceTitle)).selected,
          isTrue,
        );
        // Beside the list there is nothing to go back to.
        expect(find.byType(BackButton), findsNothing);

        await tapRow(tester, ru.language);
        expect(
          find.text(settingsStubLabel(LanguageSettingsRoute.location)),
          findsOneWidget,
        );
        expect(
          tester.widget<AppGroupedTile>(row(ru.appearanceTitle)).selected,
          isFalse,
        );
        expect(
          tester.widget<AppGroupedTile>(row(ru.language)).selected,
          isTrue,
        );

        // Swapped, not stacked: one step back is the placeholder, not the
        // section looked at before.
        harness.router.pop();
        await tester.pumpAndSettle();
        expect(find.byType(SettingsPlaceholderPane), findsOneWidget);
      },
    );

    testWidgets('two panes: the card stays marked while the profile is open', (
      tester,
    ) async {
      await SettingsHarness().pump(
        tester,
        window: PaneWindow.desktop,
        initialLocation: ProfileEditRoute.location,
      );

      expect(
        tester
            .widget<SettingsProfileCard>(find.byType(SettingsProfileCard))
            .selected,
        isTrue,
      );
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final MapEntry(key: theme, value: dark) in {
        'light': false,
        'dark': true,
      }.entries) {
        testGoldens('settings, ${window.name}, $theme', (tester) async {
          await SettingsHarness(
            alerts: 5,
          ).pump(tester, window: window, dark: dark);
          await screenMatchesGolden(tester, 'settings_${window.name}_$theme');
        });
      }
    }
  });
}
