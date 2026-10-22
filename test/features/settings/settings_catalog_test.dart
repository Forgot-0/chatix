import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/settings/presentation/utils/settings_catalog.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

void main() {
  final ru = AppLocalizationsRu();

  group('SettingsSection.at', () {
    test('each section owns its own location and everything under it', () {
      for (final section in SettingsSection.values) {
        if (!section.opensInPane) continue;
        expect(SettingsSection.at(section.location), section);
        expect(SettingsSection.at('${section.location}/deeper'), section);
      }
    });

    test('the longest match wins: Privacy keeps the devices it opened', () {
      expect(
        SettingsSection.at(SessionsRoute.location),
        SettingsSection.privacy,
      );
      expect(
        SettingsSection.at(DevicesSettingsRoute.location),
        SettingsSection.devices,
      );
      expect(
        SettingsSection.at(SettingsFolderEditorRoute.locationOf('f1')),
        SettingsSection.folders,
      );
      expect(
        SettingsSection.at(ProfileEditRoute.location),
        SettingsSection.profile,
      );
    });

    test('the list itself, and anywhere else, marks nothing', () {
      expect(SettingsSection.at(SettingsRoute.location), isNull);
      expect(SettingsSection.at(ChatsRoute.location), isNull);
      // Not a prefix match on the word: `/settingsx` is not settings.
      expect(SettingsSection.at('/settings/dataset'), isNull);
      // The alerts list is a page over the app, never a section.
      expect(SettingsSection.at(NotificationsRoute.location), isNull);
    });
  });

  group('SettingsSection.groups', () {
    test('every row once, the developer row only when opened', () {
      final closed = SettingsSection.groups(developer: false).expand((g) => g);
      final open = SettingsSection.groups(developer: true).expand((g) => g);

      expect(closed, isNot(contains(SettingsSection.developer)));
      expect(open.last, SettingsSection.developer);
      expect(open.toSet().length, open.length);
      // The card is the profile's way in, not a row.
      expect(open, isNot(contains(SettingsSection.profile)));
    });

    test('one colour per row', () {
      final rows = SettingsSection.groups(developer: true).expand((g) => g);
      final plates = rows.map((section) => section.plate).toList();
      expect(plates.toSet().length, plates.length);
    });
  });

  group('searchSettings', () {
    final index = settingsSearchIndex(ru, developer: false, desktop: false);

    test('a blank query finds nothing — the list is what it shows', () {
      expect(searchSettings(index, ''), isEmpty);
      expect(searchSettings(index, '   '), isEmpty);
    });

    test('matches anywhere in a name, case aside', () {
      final hits = searchSettings(index, 'ОФОРМ');
      expect(hits.map((hit) => hit.title), [ru.appearanceTitle]);
      expect(hits.single.isSection, isTrue);
    });

    test('sections first, then the rows inside them', () {
      final hits = searchSettings(index, 'уведомл');

      final sections = hits.where((hit) => hit.isSection).toList();
      final rows = hits.where((hit) => !hit.isSection).toList();
      expect(sections.map((hit) => hit.section), [
        SettingsSection.notificationsFeed,
        SettingsSection.notifications,
      ]);
      expect(hits, [...sections, ...rows]);
    });

    test('a row leads to the section it lives in', () {
      final hits = searchSettings(index, ru.chatWallpaper);
      expect(hits.single.section, SettingsSection.appearance);
      expect(hits.single.isSection, isFalse);
    });

    test('the same name under the same section is shown once', () {
      final doubled = [
        ...index,
        SettingsSearchEntry(SettingsSection.appearance, ru.theme),
      ];
      expect(
        searchSettings(doubled, ru.theme).where((hit) => hit.title == ru.theme),
        hasLength(1),
      );
    });

    test('desktop-only rows and the developer menu only where they exist', () {
      expect(searchSettings(index, ru.settingsKeyboardSection), isEmpty);
      expect(searchSettings(index, ru.devMenuTitle), isEmpty);

      final everything = settingsSearchIndex(
        ru,
        developer: true,
        desktop: true,
      );
      expect(
        searchSettings(everything, ru.settingsKeyboardSection).single.section,
        SettingsSection.appearance,
      );
      expect(
        searchSettings(everything, ru.devMenuTitle).single.section,
        SettingsSection.developer,
      );
    });
  });
}
