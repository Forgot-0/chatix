import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/storage/cache/attachment_cache_usage.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/features/settings/presentation/providers/avatar_accent_provider.dart';
import 'package:chatix/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:chatix/features/settings/presentation/widgets/accent_picker.dart';
import 'package:chatix/features/settings/presentation/widgets/wallpaper_gallery.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The appearance screen's promise is that nothing on it needs a restart and
/// nothing on it is forgotten by one. Both halves are checked here: the live
/// theme after each tap, and a second container standing in for the next
/// launch.
class _AppearanceHarness extends ConsumerWidget {
  const _AppearanceHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      theme: ref.watch(lightThemeProvider),
      darkTheme: ref.watch(darkThemeProvider),
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppearanceSettingsScreen(),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int cleared;

  /// Settling by hand rather than with `pumpAndSettle`: the preview's typing
  /// indicator repeats for as long as it is on screen, which is the point of
  /// it, so nothing here ever reaches a still frame. A couple of frames is
  /// all any of these interactions need.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  setUp(() => cleared = 0);

  Future<SharedPreferences> pumpAppearance(
    WidgetTester tester, {
    int cacheUsage = 0,
    AvatarAccentResult eyedropper = const AvatarAccentResult(
      AvatarAccentStatus.noAvatar,
    ),
    Size viewport = const Size(1200, 3600),
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          // The real one walks a cache directory the test platform has no
          // plugin for; what it would answer is not what is under test here.
          attachmentCacheUsageProvider.overrideWith((ref) async => cacheUsage),
          clearAttachmentCacheProvider.overrideWithValue(() async {
            cleared++;
            return cacheUsage;
          }),
          avatarAccentPickerProvider.overrideWithValue(() async => eyedropper),
        ],
        child: const _AppearanceHarness(),
      ),
    );
    await settle(tester);
    return prefs;
  }

  ThemeData activeTheme(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(AppearanceSettingsScreen)));

  ChatixTheme chatix(WidgetTester tester) =>
      activeTheme(tester).extension<ChatixTheme>()!;

  AppLocalizations strings(WidgetTester tester) => AppLocalizations.of(
    tester.element(find.byType(AppearanceSettingsScreen)),
  );

  Future<void> tapText(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder.first);
    await settle(tester);
    await tester.tap(finder.first);
    await settle(tester);
  }

  /// A second container over the same store: the next launch.
  AppearanceSettings relaunch(SharedPreferences prefs) {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container.read(appearanceProvider);
  }

  testWidgets('picking a density re-themes the app without a restart', (
    tester,
  ) async {
    final prefs = await pumpAppearance(tester);

    expect(chatix(tester).density, AppDensity.cozy);

    await tapText(tester, strings(tester).densityComfortable);

    expect(chatix(tester).density, AppDensity.comfortable);
    expect(relaunch(prefs).density, AppDensity.comfortable);
  });

  testWidgets('switching to dark repaints on the dark ground', (tester) async {
    await pumpAppearance(tester);
    expect(activeTheme(tester).brightness, Brightness.light);

    await tapText(tester, strings(tester).darkMode);

    expect(activeTheme(tester).brightness, Brightness.dark);
  });

  testWidgets('AMOLED takes the dark ground all the way to black', (
    tester,
  ) async {
    final prefs = await pumpAppearance(tester);
    await tapText(tester, strings(tester).darkMode);

    expect(chatix(tester).chatBackground, isNot(Colors.black));

    await tapText(tester, strings(tester).amoledTitle);

    expect(chatix(tester).chatBackground, AppAmoled.canvas);
    expect(activeTheme(tester).colorScheme.surface, AppAmoled.canvas);
    // On black an incoming bubble needs the hairline it goes without on the
    // ordinary dark ground.
    expect(chatix(tester).bubbleIncomingBorder, isNot(Colors.transparent));
    expect(relaunch(prefs).amoled, isTrue);
  });

  testWidgets('AMOLED leaves the light theme alone', (tester) async {
    await pumpAppearance(tester);
    await tapText(tester, strings(tester).amoledTitle);

    expect(activeTheme(tester).brightness, Brightness.light);
    expect(chatix(tester).chatBackground, isNot(Colors.black));
  });

  testWidgets('picking an accent recolours primary everywhere', (tester) async {
    await pumpAppearance(tester);
    expect(activeTheme(tester).colorScheme.primary, AppPalette.violet);

    final swatches = find.descendant(
      of: find.byType(AccentPicker),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(swatches.at(1));
    await settle(tester);
    await tester.tap(swatches.at(1));
    await settle(tester);

    final theme = activeTheme(tester);
    expect(theme.colorScheme.primary, AppPalette.accentSeeds[1]);
    expect(
      theme.extension<ChatixTheme>()!.wallpaperSeed,
      theme.colorScheme.primary,
    );
  });

  testWidgets('the eyedropper puts the photo\'s colour on the theme', (
    tester,
  ) async {
    const fromPhoto = Color(0xFF1E88A6);

    final prefs = await pumpAppearance(
      tester,
      eyedropper: const AvatarAccentResult(AvatarAccentStatus.found, fromPhoto),
    );

    await tapText(tester, strings(tester).accentFromAvatar);

    expect(activeTheme(tester).colorScheme.primary, fromPhoto);
    expect(relaunch(prefs).accentSeed, fromPhoto);

    // A colour off the curated ramp gets a swatch of its own, so it can be
    // returned to after trying the others.
    expect(find.bySemanticsLabel(strings(tester).accentCustom), findsOneWidget);
  });

  testWidgets('an avatar with no colour in it says so and changes nothing', (
    tester,
  ) async {
    await pumpAppearance(
      tester,
      eyedropper: const AvatarAccentResult(AvatarAccentStatus.noColour),
    );

    await tapText(tester, strings(tester).accentFromAvatar);

    expect(activeTheme(tester).colorScheme.primary, AppPalette.violet);
    expect(find.text(strings(tester).accentFromAvatarEmpty), findsOneWidget);
  });

  testWidgets('picking a wallpaper reaches the theme', (tester) async {
    final prefs = await pumpAppearance(tester);
    expect(chatix(tester).wallpaperStyle, AppWallpaper.aurora);

    final tile = find.descendant(
      of: find.byType(WallpaperGallery),
      matching: find.text(strings(tester).wallpaperNebula),
    );
    await tester.ensureVisible(tile);
    await settle(tester);
    await tester.tap(tile);
    await settle(tester);

    expect(chatix(tester).wallpaperStyle, AppWallpaper.nebula);
    expect(relaunch(prefs).wallpaper, AppWallpaper.nebula);
  });

  testWidgets('the corner slider reshapes the bubbles and is written down', (
    tester,
  ) async {
    final prefs = await pumpAppearance(tester);
    expect(chatix(tester).bubbleRadius, AppearanceSettings.defaultBubbleRadius);

    // The sliders in document order: wallpaper intensity, wallpaper pattern,
    // bubble corners, cache limit.
    final corners = find.byType(Slider).at(2);
    await tester.ensureVisible(corners);
    await settle(tester);
    await tester.drag(corners, const Offset(-200, 0));
    await settle(tester);

    final radius = chatix(tester).bubbleRadius;
    expect(radius, lessThan(AppearanceSettings.defaultBubbleRadius));
    expect(radius, greaterThanOrEqualTo(AppearanceSettings.minBubbleRadius));

    // A drag writes on release, not on every frame it passed through.
    expect(relaunch(prefs).bubbleRadius, radius);
  });

  testWidgets('turning the anchor off makes every corner the same', (
    tester,
  ) async {
    final prefs = await pumpAppearance(tester);
    expect(
      chatix(tester).bubbleAnchorRadius,
      lessThan(chatix(tester).bubbleRadius),
    );

    await tapText(tester, strings(tester).bubbleAnchor);

    expect(chatix(tester).bubbleAnchorRadius, chatix(tester).bubbleRadius);
    expect(relaunch(prefs).bubbleAnchored, isFalse);
  });

  testWidgets('auto-download is set per kind and survives a restart', (
    tester,
  ) async {
    final prefs = await pumpAppearance(tester);
    final l10n = strings(tester);

    final dropdown = find
        .byType(DropdownButton<MediaAutoDownload>)
        .first; // photos
    await tester.ensureVisible(dropdown);
    await settle(tester);
    await tester.tap(dropdown);
    await settle(tester);

    await tester.tap(find.text(l10n.autoDownloadNever).last);
    await settle(tester);

    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(mediaSettingsProvider).policyFor(MediaKind.photo),
      MediaAutoDownload.never,
    );
    // The other kinds keep their own defaults rather than following photos.
    expect(
      container.read(mediaSettingsProvider).policyFor(MediaKind.voice),
      MediaAutoDownload.always,
    );
  });

  testWidgets('an empty cache offers nothing to clear', (tester) async {
    await pumpAppearance(tester);

    expect(find.text(strings(tester).cacheEmpty), findsOneWidget);

    final button = find.widgetWithText(TextButton, strings(tester).cacheClear);
    expect(tester.widget<TextButton>(button).onPressed, isNull);
  });

  testWidgets('clearing a full cache reports what it freed', (tester) async {
    await pumpAppearance(tester, cacheUsage: 12 * 1024 * 1024);
    final l10n = strings(tester);

    expect(
      find.text(l10n.cacheInUse(l10n.sizeMegabytes('12'))),
      findsOneWidget,
    );

    await tapText(tester, l10n.cacheClear);

    expect(cleared, 1);
    expect(
      find.text(l10n.cacheCleared(l10n.sizeMegabytes('12'))),
      findsOneWidget,
    );
  });

  group('on a phone', () {
    for (final dark in [false, true]) {
      testWidgets(
        'lays out without overflowing in ${dark ? 'dark' : 'light'}',
        (tester) async {
          await pumpAppearance(
            tester,
            cacheUsage: 3 * 1024 * 1024,
            viewport: const Size(390, 844),
          );

          if (dark) {
            await tapText(tester, strings(tester).darkMode);
            await tapText(tester, strings(tester).amoledTitle);
          }

          // Every section gets scrolled past: an overflow anywhere down the
          // list throws, and a throw fails the test.
          final list = find.byType(Scrollable).first;
          for (var i = 0; i < 12; i++) {
            await tester.drag(list, const Offset(0, -400));
            await settle(tester);
          }

          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  testWidgets('resetting returns the app to the default appearance', (
    tester,
  ) async {
    final prefs = await pumpAppearance(tester);

    await tapText(tester, strings(tester).densityCompact);
    await tapText(tester, strings(tester).amoledTitle);
    expect(chatix(tester).density, AppDensity.compact);

    await tapText(tester, strings(tester).resetAppearance);

    expect(chatix(tester).density, AppDensity.cozy);
    expect(relaunch(prefs), const AppearanceSettings());
  });
}
