import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.isSupported(locale);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

final defaultLocaleProvider = Provider<Locale>((ref) => const Locale('en'));

final translationsProvider = Provider<Map<String, String>>((ref) {
  final locale = ref.watch(defaultLocaleProvider);
  return localizedValues[locale.languageCode] ?? localizedValues['en'] ?? {};
});

class LocalizationUtils {
  static Locale getDeviceLocale(BuildContext context) {
    return Localizations.localeOf(context);
  }

  static Locale findSupportedLocale(Locale deviceLocale) {
    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == deviceLocale.languageCode) {
        return locale;
      }
    }

    return const Locale('en');
  }

  static String getLocaleName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'es':
        return 'Español';
      case 'fr':
        return 'Français';
      case 'de':
        return 'Deutsch';
      case 'ja':
        return '日本語';
      case 'bn':
        return 'বাংলা';
      default:
        return locale.languageCode;
    }
  }
}
