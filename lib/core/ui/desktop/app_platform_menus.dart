import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The menu bar along the top of a Mac's screen.
///
/// The app menu — About, Settings… (⌘,), Services, Hide, Quit — an Edit
/// menu and a Window menu, in the order every Mac app has them. Edit's items
/// are the text field's own actions run on whatever has the focus, so ⌘C,
/// ⌘V and the rest do in the menu exactly what they do from the keyboard —
/// a picture pasted into the composer included. Anywhere but macOS there is
/// no such bar, and this is only [child].
class AppPlatformMenus extends StatelessWidget {
  const AppPlatformMenus({
    super.key,
    required this.onOpenSettings,
    required this.child,
  });

  final VoidCallback onOpenSettings;
  final Widget child;

  /// Whether this platform draws the bar at all.
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return child;

    return PlatformMenuBar(menus: menusFor(context), child: child);
  }

  /// The menus themselves — apart from the bar, so a test can read them.
  List<PlatformMenuItem> menusFor(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const cause = SelectionChangedCause.keyboard;

    PlatformMenuItem provided(PlatformProvidedMenuItemType type) =>
        PlatformProvidedMenuItem(type: type);

    PlatformMenuItem command(
      String label,
      LogicalKeyboardKey key,
      Intent intent, {
      bool shift = false,
    }) => PlatformMenuItem(
      label: label,
      shortcut: SingleActivator(key, meta: true, shift: shift),
      onSelectedIntent: intent,
    );

    return [
      PlatformMenu(
        // macOS titles this menu with the app's own name whatever it is
        // given; the label is for everything else that reads it.
        label: AppConstants.appName,
        menus: [
          PlatformMenuItemGroup(
            members: [provided(PlatformProvidedMenuItemType.about)],
          ),
          PlatformMenuItemGroup(
            members: [
              PlatformMenuItem(
                label: l10n.menuSettings,
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.comma,
                  meta: true,
                ),
                onSelected: onOpenSettings,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [provided(PlatformProvidedMenuItemType.servicesSubmenu)],
          ),
          PlatformMenuItemGroup(
            members: [
              provided(PlatformProvidedMenuItemType.hide),
              provided(PlatformProvidedMenuItemType.hideOtherApplications),
              provided(PlatformProvidedMenuItemType.showAllApplications),
            ],
          ),
          PlatformMenuItemGroup(
            members: [provided(PlatformProvidedMenuItemType.quit)],
          ),
        ],
      ),
      PlatformMenu(
        label: l10n.menuEdit,
        menus: [
          PlatformMenuItemGroup(
            members: [
              command(
                l10n.menuUndo,
                LogicalKeyboardKey.keyZ,
                const UndoTextIntent(cause),
              ),
              command(
                l10n.menuRedo,
                LogicalKeyboardKey.keyZ,
                const RedoTextIntent(cause),
                shift: true,
              ),
            ],
          ),
          PlatformMenuItemGroup(
            members: [
              command(
                l10n.menuCut,
                LogicalKeyboardKey.keyX,
                const CopySelectionTextIntent.cut(cause),
              ),
              command(
                l10n.menuCopy,
                LogicalKeyboardKey.keyC,
                CopySelectionTextIntent.copy,
              ),
              command(
                l10n.menuPaste,
                LogicalKeyboardKey.keyV,
                const PasteTextIntent(cause),
              ),
              command(
                l10n.menuSelectAll,
                LogicalKeyboardKey.keyA,
                const SelectAllTextIntent(cause),
              ),
            ],
          ),
        ],
      ),
      PlatformMenu(
        label: l10n.menuWindow,
        menus: [
          PlatformMenuItemGroup(
            members: [
              provided(PlatformProvidedMenuItemType.minimizeWindow),
              provided(PlatformProvidedMenuItemType.zoomWindow),
            ],
          ),
          PlatformMenuItemGroup(
            members: [provided(PlatformProvidedMenuItemType.toggleFullScreen)],
          ),
          PlatformMenuItemGroup(
            members: [
              provided(PlatformProvidedMenuItemType.arrangeWindowsInFront),
            ],
          ),
        ],
      ),
    ];
  }
}
