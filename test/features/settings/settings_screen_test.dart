import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/settings/send_shortcut.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/settings/presentation/screens/settings_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/pane_frame.dart';

class _FakeNotificationBadge extends NotificationBadgeController {
  _FakeNotificationBadge(this._count);

  final int _count;

  @override
  int build() => _count;
}

/// The settings page: what a desktop adds to it (the keyboard section) and
/// how wide it lets itself grow.
void main() {
  final ru = AppLocalizationsRu();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    SendShortcut shortcut = SendShortcut.enter,
    int alerts = 0,
  }) async {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sendShortcutStoreProvider.overrideWithValue(
          InMemorySendShortcutStore(shortcut),
        ),
        notificationBadgeProvider.overrideWith(
          () => _FakeNotificationBadge(alerts),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(window: window, child: const SettingsScreen()),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder sendSwitch() => find.widgetWithText(
    SwitchListTile,
    ru.settingsSendWithModifierEnter(ru.keyboardControlKey),
  );

  group('the keyboard section', () {
    testWidgets(
      'a desktop chooses which Enter sends',
      (tester) async {
        final container = await pump(tester);

        expect(find.text(ru.settingsKeyboardSection), findsOneWidget);
        expect(find.text(ru.settingsSendWithModifierEnterOff), findsOneWidget);

        await tester.tap(sendSwitch());
        await tester.pumpAndSettle();

        expect(
          container.read(sendShortcutProvider),
          SendShortcut.modifierEnter,
        );
        expect(
          find.text(ru.settingsSendWithModifierEnterOn(ru.keyboardControlKey)),
          findsOneWidget,
        );

        await tester.tap(sendSwitch());
        await tester.pumpAndSettle();
        expect(container.read(sendShortcutProvider), SendShortcut.enter);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('a Mac says ⌘', (tester) async {
      await pump(tester);

      expect(
        find.text(ru.settingsSendWithModifierEnter(ru.keyboardCommandKey)),
        findsOneWidget,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

    testWidgets('a phone has no Enter to choose', (tester) async {
      await pump(tester);

      expect(find.text(ru.settingsKeyboardSection), findsNothing);
    }, variant: TargetPlatformVariant.mobile());
  });

  group('notifications', () {
    testWidgets('the alerts list is a row of its own, with its count', (
      tester,
    ) async {
      await pump(tester, alerts: 5);

      final row = find.widgetWithText(ListTile, ru.notifications);
      expect(row, findsOneWidget);
      expect(
        find.descendant(of: row, matching: find.text(ru.notificationsFeedHint)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('5')),
        findsOneWidget,
      );
      // Read out in words; the tile merges it into its own label.
      expect(
        find.descendant(
          of: row,
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
      await pump(tester);

      final row = find.widgetWithText(ListTile, ru.notifications);
      expect(
        find.descendant(of: row, matching: find.byType(Badge)),
        findsNothing,
      );
    });

    testWidgets('its preferences keep their own row, named apart', (
      tester,
    ) async {
      await pump(tester);

      expect(find.text(ru.notificationsAndSounds), findsOneWidget);
      // One "Notifications" on the page, not two rows of the same name.
      expect(find.text(ru.notifications), findsOneWidget);
    });
  });

  testWidgets('on a wide pane the list keeps to a readable column', (
    tester,
  ) async {
    await pump(tester, window: PaneWindow.desktop);

    final column = tester.getRect(find.byType(ListView));
    expect(column.width, AppContentWidths.form);
    // Centred in the pane, not pinned to its start.
    final pane = tester.getRect(find.byType(AppContentWidth));
    expect(column.center.dx, closeTo(pane.center.dx, 0.5));
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final MapEntry(key: theme, value: dark) in {
        'light': false,
        'dark': true,
      }.entries) {
        testGoldens('settings, ${window.name}, $theme', (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.windows;
          try {
            await pump(
              tester,
              window: window,
              dark: dark,
              shortcut: SendShortcut.modifierEnter,
              alerts: 5,
            );
            await screenMatchesGolden(
              tester,
              'settings_desktop_${window.name}_$theme',
            );
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        });
      }
    }
  });
}
