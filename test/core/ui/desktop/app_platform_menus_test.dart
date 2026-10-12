import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/desktop/app_platform_menus.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

/// Takes the menus the bar would hand to macOS.
class _RecordingMenuDelegate extends PlatformMenuDelegate {
  List<PlatformMenuItem> menus = const [];

  @override
  void setMenus(List<PlatformMenuItem> topLevelMenus) => menus = topLevelMenus;

  @override
  void clearMenus() => menus = const [];

  @override
  bool debugLockDelegate(BuildContext context) => true;

  @override
  bool debugUnlockDelegate(BuildContext context) => true;
}

void main() {
  final l10n = AppLocalizationsEn();

  late _RecordingMenuDelegate delegate;
  late PlatformMenuDelegate original;
  var settingsOpened = 0;

  setUp(() {
    settingsOpened = 0;
    delegate = _RecordingMenuDelegate();
    original = WidgetsBinding.instance.platformMenuDelegate;
    WidgetsBinding.instance.platformMenuDelegate = delegate;
  });

  tearDown(() => WidgetsBinding.instance.platformMenuDelegate = original);

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => AppPlatformMenus(
          onOpenSettings: () => settingsOpened++,
          child: child!,
        ),
        home: const Scaffold(body: Text('app')),
      ),
    );
    await tester.pump();
  }

  Iterable<PlatformMenuItem> flatten(List<PlatformMenuItem> items) sync* {
    for (final item in items) {
      yield item;
      if (item is PlatformMenu) yield* flatten(item.menus);
      if (item is PlatformMenuItemGroup) yield* flatten(item.members);
    }
  }

  testWidgets(
    'a Mac gets the app, Edit and Window menus',
    (tester) async {
      await pump(tester);

      expect(find.byType(PlatformMenuBar), findsOneWidget);
      expect(delegate.menus.map((menu) => menu.label), [
        'ChatiX',
        l10n.menuEdit,
        l10n.menuWindow,
      ]);

      final provided = flatten(
        delegate.menus,
      ).whereType<PlatformProvidedMenuItem>().map((item) => item.type).toSet();
      expect(
        provided,
        containsAll([
          PlatformProvidedMenuItemType.about,
          PlatformProvidedMenuItemType.quit,
          PlatformProvidedMenuItemType.hide,
          PlatformProvidedMenuItemType.minimizeWindow,
        ]),
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'Settings… is ⌘, and opens the settings',
    (tester) async {
      await pump(tester);

      final settings = flatten(
        delegate.menus,
      ).singleWhere((item) => item.label == l10n.menuSettings);
      expect(
        settings.shortcut,
        const SingleActivator(LogicalKeyboardKey.comma, meta: true),
      );

      settings.onSelected!();
      expect(settingsOpened, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'Edit runs the text field\'s own actions, with their keys',
    (tester) async {
      await pump(tester);

      final paste = flatten(
        delegate.menus,
      ).singleWhere((item) => item.label == l10n.menuPaste);
      expect(paste.onSelectedIntent, isA<PasteTextIntent>());
      // SingleActivator has no ==; the keys are what matter.
      final keys = paste.shortcut! as SingleActivator;
      expect(keys.trigger, LogicalKeyboardKey.keyV);
      expect((keys.meta, keys.control, keys.shift), (true, false, false));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'nowhere else is there a menu bar',
    (tester) async {
      await pump(tester);

      expect(find.byType(PlatformMenuBar), findsNothing);
      expect(delegate.menus, isEmpty);
      expect(find.text('app'), findsOneWidget);
    },
    variant: TargetPlatformVariant.all(excluding: {TargetPlatform.macOS}),
  );
}
