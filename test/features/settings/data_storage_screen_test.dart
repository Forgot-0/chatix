import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/features/settings/presentation/screens/data_storage_screen.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/pane_frame.dart';
import '../../helpers/settings_harness.dart';

const int _mb = 1024 * 1024;

/// Settings → Data and storage: auto-download as two switches per kind,
/// the cache against its limit, and the reset.
void main() {
  final ru = AppLocalizationsRu();

  Future<SettingsHarness> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    int cacheUsage = 0,
    Size? surface,
  }) async {
    final harness = SettingsHarness(
      cacheUsage: cacheUsage,
      screens: const {DataStorageSettingsRoute.location: DataStorageScreen()},
    );
    await harness.pump(
      tester,
      window: window,
      dark: dark,
      initialLocation: DataStorageSettingsRoute.location,
      surface: surface,
    );
    return harness;
  }

  MediaSettings settings(SettingsHarness harness) =>
      harness.container.read(mediaSettingsProvider);

  /// The [kind] switch in the group captioned [network].
  Finder kindSwitch(String network, String kind) => find.descendant(
    of: find.ancestor(
      of: find.text(network),
      matching: find.byType(AppGroupedSection),
    ),
    matching: find.widgetWithText(AppGroupedSwitchTile, kind),
  );

  bool isOn(WidgetTester tester, Finder tile) =>
      tester.widget<AppGroupedSwitchTile>(tile).value;

  Future<void> toggle(WidgetTester tester, Finder tile) async {
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();
  }

  group('auto-download', () {
    testWidgets('the defaults, as switches per network', (tester) async {
      await pump(tester, surface: const Size(390, 1800));

      // Photos and videos on Wi-Fi only, files never, voice everywhere.
      for (final (kind, mobile, wifi) in [
        (ru.autoDownloadPhotos, false, true),
        (ru.autoDownloadVideos, false, true),
        (ru.autoDownloadFiles, false, false),
        (ru.autoDownloadVoice, true, true),
      ]) {
        expect(
          isOn(tester, kindSwitch(ru.autoDownloadOnMobile, kind)),
          mobile,
          reason: '$kind on mobile',
        );
        expect(
          isOn(tester, kindSwitch(ru.autoDownloadOnWifi, kind)),
          wifi,
          reason: '$kind on Wi-Fi',
        );
      }
    });

    testWidgets('mobile on brings Wi-Fi with it, and is written down', (
      tester,
    ) async {
      final harness = await pump(tester, surface: const Size(390, 1800));

      await toggle(
        tester,
        kindSwitch(ru.autoDownloadOnMobile, ru.autoDownloadFiles),
      );

      expect(
        settings(harness).policyFor(MediaKind.file),
        MediaAutoDownload.always,
      );
      expect(
        isOn(tester, kindSwitch(ru.autoDownloadOnWifi, ru.autoDownloadFiles)),
        isTrue,
      );

      // The next launch reads the same answer.
      final next = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(harness.prefs)],
      );
      addTearDown(next.dispose);
      expect(
        next.read(mediaSettingsProvider).policyFor(MediaKind.file),
        MediaAutoDownload.always,
      );
    });

    testWidgets('Wi-Fi off takes mobile with it', (tester) async {
      final harness = await pump(tester, surface: const Size(390, 1800));

      await toggle(
        tester,
        kindSwitch(ru.autoDownloadOnWifi, ru.autoDownloadVoice),
      );

      expect(
        settings(harness).policyFor(MediaKind.voice),
        MediaAutoDownload.never,
      );
      expect(
        isOn(tester, kindSwitch(ru.autoDownloadOnMobile, ru.autoDownloadVoice)),
        isFalse,
      );
      // The other kinds keep their own answers.
      expect(
        settings(harness).policyFor(MediaKind.photo),
        MediaAutoDownload.wifiOnly,
      );
    });

    testWidgets('the reset puts downloads back and leaves the cache limit', (
      tester,
    ) async {
      final harness = await pump(tester, surface: const Size(390, 1800));
      final controller = harness.container.read(mediaSettingsProvider.notifier);
      await controller.setAutoDownload(
        MediaKind.photo,
        MediaAutoDownload.never,
      );
      await controller.setVideoNoteAutoplay(MediaAutoplay.never);
      await controller.setCacheLimit(MediaSettings.cacheLimitSteps.last);
      await tester.pumpAndSettle();

      final reset = find.widgetWithText(AppGroupedTile, ru.dataStorageReset);
      await tester.ensureVisible(reset);
      await tester.pumpAndSettle();
      await tester.tap(reset);
      await tester.pump();

      expect(
        settings(harness).policyFor(MediaKind.photo),
        MediaKind.photo.defaultPolicy,
      );
      expect(settings(harness).videoNoteAutoplay, MediaAutoplay.wifiOnly);
      expect(
        settings(harness).cacheLimitBytes,
        MediaSettings.cacheLimitSteps.last,
      );
      expect(find.text(ru.dataStorageResetDone), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('the cache', () {
    testWidgets('what it holds against its limit', (tester) async {
      await pump(tester, cacheUsage: 12 * _mb);

      expect(
        find.text(
          ru.dataStorageUsageOf(
            ru.sizeMegabytes('12'),
            ru.sizeMegabytes('256'),
          ),
        ),
        findsOneWidget,
      );
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(12 / 256, 1e-9));
    });

    testWidgets('an empty cache offers nothing to clear', (tester) async {
      await pump(tester);

      expect(find.text(ru.cacheEmpty), findsOneWidget);
      final clear = tester.widget<AppGroupedTile>(
        find.widgetWithText(AppGroupedTile, ru.cacheClear),
      );
      expect(clear.enabled, isFalse);
    });

    testWidgets('clearing asks first, then says what it freed', (tester) async {
      final harness = await pump(tester, cacheUsage: 12 * _mb);

      await tester.tap(find.widgetWithText(AppGroupedTile, ru.cacheClear));
      await tester.pumpAndSettle();

      expect(find.text(ru.dataStorageClearConfirmTitle), findsOneWidget);
      expect(
        find.text(ru.dataStorageClearConfirmBody(ru.sizeMegabytes('12'))),
        findsOneWidget,
      );

      // Cancelling clears nothing.
      await tester.tap(find.text(ru.cancel));
      await tester.pumpAndSettle();
      expect(harness.cleared, 0);

      await tester.tap(find.widgetWithText(AppGroupedTile, ru.cacheClear));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(ru.cacheClear),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(harness.cleared, 1);
      expect(
        find.text(ru.cacheCleared(ru.sizeMegabytes('12'))),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 3));
    });
  });

  testWidgets('on a phone it lays out without overflowing', (tester) async {
    await pump(tester, cacheUsage: 3 * _mb);

    final list = find.byType(Scrollable).last;
    for (var i = 0; i < 6; i++) {
      await tester.drag(list, const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final MapEntry(key: theme, value: dark) in {
        'light': false,
        'dark': true,
      }.entries) {
        testGoldens('data and storage, ${window.name}, $theme', (tester) async {
          await pump(tester, window: window, dark: dark, cacheUsage: 96 * _mb);
          await screenMatchesGolden(
            tester,
            'data_storage_${window.name}_$theme',
          );
        });
      }
    }
  });
}
