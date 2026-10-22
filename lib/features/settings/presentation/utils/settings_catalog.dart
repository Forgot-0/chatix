import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/utils/text_match.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Every place the settings list leads to: where it is, the glyph and the
/// colour its row leads with, and what it is called.
///
/// One colour per row, each from [AppPlatePalette], so a row is found by
/// its colour as much as by its name. [profile] has no row of its own — the
/// card at the top is its way in — but it is a section all the same: in two
/// panes the card stays marked while the profile is open beside it.
enum SettingsSection {
  profile(ProfileRoute.location, Icons.person_rounded, AppPlatePalette.violet),
  notificationsFeed(
    NotificationsRoute.location,
    Icons.notifications_rounded,
    AppPlatePalette.coral,
  ),
  notifications(
    NotificationSettingsRoute.location,
    Icons.volume_up_rounded,
    AppPlatePalette.orchid,
  ),
  privacy(
    PrivacySettingsRoute.location,
    Icons.lock_rounded,
    AppPlatePalette.azure,
  ),
  dataStorage(
    DataStorageSettingsRoute.location,
    Icons.pie_chart_rounded,
    AppPlatePalette.mint,
  ),
  devices(
    DevicesSettingsRoute.location,
    Icons.devices_rounded,
    AppPlatePalette.amber,
  ),
  appearance(
    AppearanceSettingsRoute.location,
    Icons.palette_rounded,
    AppPlatePalette.violet,
  ),
  folders(
    SettingsFoldersRoute.location,
    Icons.folder_rounded,
    AppPlatePalette.moss,
  ),
  language(
    LanguageSettingsRoute.location,
    Icons.translate_rounded,
    AppPlatePalette.clay,
  ),
  about(
    AboutSettingsRoute.location,
    Icons.info_rounded,
    AppPlatePalette.graphite,
  ),
  developer(
    DeveloperSettingsRoute.location,
    Icons.code_rounded,
    AppPlatePalette.indigo,
  );

  const SettingsSection(this.location, this.icon, this.plate);

  final String location;
  final IconData icon;
  final Color plate;

  /// Whether it opens in the settings pane. The alerts list is a page over
  /// the whole app instead — the bell on the chats list opens it too, and
  /// it is not a setting.
  bool get opensInPane => this != SettingsSection.notificationsFeed;

  String title(AppLocalizations l10n) => switch (this) {
    SettingsSection.profile => l10n.profile,
    SettingsSection.notificationsFeed => l10n.notifications,
    SettingsSection.notifications => l10n.notificationsAndSounds,
    SettingsSection.privacy => l10n.privacySettingsTitle,
    SettingsSection.dataStorage => l10n.dataStorageTitle,
    SettingsSection.devices => l10n.privacyDevices,
    SettingsSection.appearance => l10n.appearanceTitle,
    SettingsSection.folders => l10n.settingsChatFolders,
    SettingsSection.language => l10n.language,
    SettingsSection.about => l10n.aboutTitle,
    SettingsSection.developer => l10n.devMenuTitle,
  };

  /// The section [location] is inside — the row a two-pane list keeps
  /// marked — or null on the settings page itself and anywhere else.
  ///
  /// The longest match wins: the devices Privacy opens
  /// (`/settings/privacy/devices`) belong to Privacy, which is where they
  /// were reached from, while `/settings/devices` is the row of its own.
  static SettingsSection? at(String location) {
    final path = location.split('?').first.split('#').first;

    SettingsSection? best;
    for (final section in values) {
      if (!section.opensInPane) continue;
      final inside =
          path == section.location || path.startsWith('${section.location}/');
      if (!inside) continue;
      if (best == null || section.location.length > best.location.length) {
        best = section;
      }
    }
    return best;
  }

  /// The rows of the settings list, group by group, top to bottom. The
  /// developer row is there only once seven taps on the version opened it.
  static List<List<SettingsSection>> groups({required bool developer}) => [
    const [SettingsSection.notificationsFeed, SettingsSection.notifications],
    const [
      SettingsSection.privacy,
      SettingsSection.dataStorage,
      SettingsSection.devices,
    ],
    const [
      SettingsSection.appearance,
      SettingsSection.folders,
      SettingsSection.language,
    ],
    [SettingsSection.about, if (developer) SettingsSection.developer],
  ];
}

/// One thing the settings search can find: a section, or a row inside one.
@immutable
class SettingsSearchEntry {
  const SettingsSearchEntry(this.section, this.title, {this.isSection = false});

  /// Where picking it goes.
  final SettingsSection section;

  final String title;

  /// The section itself rather than a row inside it — a row is shown with
  /// its section's name under it, so "Theme" says where it lives.
  final bool isSection;

  @override
  bool operator ==(Object other) =>
      other is SettingsSearchEntry &&
      other.section == section &&
      other.title == title &&
      other.isSection == isSection;

  @override
  int get hashCode => Object.hash(section, title, isSection);

  @override
  String toString() => 'SettingsSearchEntry($section, $title)';
}

/// What the settings search looks through, in the reader's language: every
/// row of the list, then the rows inside the sections people most often
/// come looking for by name.
///
/// Only rows that really are on those screens, by the very strings those
/// screens use — so a hit always lands where the word is.
List<SettingsSearchEntry> settingsSearchIndex(
  AppLocalizations l10n, {
  required bool developer,
  required bool desktop,
}) {
  SettingsSearchEntry row(SettingsSection section, String title) =>
      SettingsSearchEntry(section, title);

  return [
    SettingsSearchEntry(SettingsSection.profile, l10n.profile, isSection: true),
    for (final group in SettingsSection.groups(developer: developer))
      for (final section in group)
        SettingsSearchEntry(section, section.title(l10n), isSection: true),

    row(SettingsSection.notifications, l10n.notificationSoundTitle),
    row(SettingsSection.notifications, l10n.notificationVibrationTitle),
    row(SettingsSection.notifications, l10n.notificationPreviewTitle),
    row(SettingsSection.notifications, l10n.quietHoursTitle),
    row(SettingsSection.privacy, l10n.blockedUsersTitle),
    row(SettingsSection.privacy, l10n.privacyPasscodeSection),
    row(SettingsSection.privacy, l10n.privacyRuleLastSeen),
    row(SettingsSection.privacy, l10n.privacyRulePhoto),
    row(SettingsSection.privacy, l10n.privacyRuleMessages),
    row(SettingsSection.privacy, l10n.privacyRuleGroupInvites),
    row(SettingsSection.privacy, l10n.privacyRuleCalls),
    row(SettingsSection.dataStorage, l10n.autoDownload),
    row(SettingsSection.dataStorage, l10n.dataStorageCacheTitle),
    row(SettingsSection.dataStorage, l10n.cacheLimit),
    row(SettingsSection.dataStorage, l10n.mediaAutoplay),
    row(SettingsSection.appearance, l10n.theme),
    row(SettingsSection.appearance, l10n.amoledTitle),
    row(SettingsSection.appearance, l10n.accentColor),
    row(SettingsSection.appearance, l10n.chatWallpaper),
    row(SettingsSection.appearance, l10n.textSize),
    row(SettingsSection.appearance, l10n.appearanceDensity),
    row(SettingsSection.appearance, l10n.bubbleShape),
    row(SettingsSection.appearance, l10n.appearanceHaptics),
    if (desktop) row(SettingsSection.appearance, l10n.settingsKeyboardSection),
    row(SettingsSection.folders, l10n.newFolder),
    row(SettingsSection.folders, l10n.hideFolderTabs),
    row(SettingsSection.about, l10n.aboutVersion),
    row(SettingsSection.about, l10n.aboutWhatsNew),
    row(SettingsSection.about, l10n.aboutLicenses),
  ];
}

/// What [query] finds in [index]: sections before the rows inside them,
/// each in the order the index lists them, matched anywhere in the title
/// with case set aside. A blank query finds nothing — the list itself is
/// what an empty search box shows.
///
/// A title that turns up twice under the same section is shown once.
List<SettingsSearchEntry> searchSettings(
  List<SettingsSearchEntry> index,
  String query,
) {
  final needle = query.trim();
  if (needle.isEmpty) return const [];

  final sections = <SettingsSearchEntry>[];
  final rows = <SettingsSearchEntry>[];
  final seen = <(SettingsSection, String)>{};

  for (final entry in index) {
    if (findMatches(entry.title, needle, limit: 1).isEmpty) continue;
    if (!seen.add((entry.section, entry.title.toLowerCase()))) continue;
    (entry.isSection ? sections : rows).add(entry);
  }

  return [...sections, ...rows];
}
