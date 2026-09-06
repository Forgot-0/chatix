import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/providers/localization_providers.dart';
import 'package:chatix/l10n/app_localizations_delegate.dart';
import 'package:chatix/l10n/l10n.dart';
import 'package:intl/intl.dart';

class LocalizationService {
  const LocalizationService(this.ref);

  final Ref ref;

  Locale get currentLocale => ref.read(persistentLocaleProvider);

  Future<void> setLocale(Locale locale) async {
    await ref.read(persistentLocaleProvider.notifier).setLocale(locale);
  }

  Future<void> resetToSystemLocale() async {
    await ref.read(persistentLocaleProvider.notifier).resetToSystemLocale();
  }

  String getLocaleName(Locale locale) {
    return LocalizationUtils.getLocaleName(locale);
  }

  List<Locale> get supportedLocales => AppLocalizations.supportedLocales;

  bool isSupported(Locale locale) => AppLocalizations.isSupported(locale);

  String formatDate(DateTime date, {String? pattern}) {
    final locale = currentLocale.toString();
    if (pattern != null) {
      return DateFormat(pattern, locale).format(date);
    }
    return DateFormat.yMMMd(locale).format(date);
  }

  String formatTime(DateTime time, {String? pattern}) {
    final locale = currentLocale.toString();
    if (pattern != null) {
      return DateFormat(pattern, locale).format(time);
    }
    return DateFormat.Hm(locale).format(time);
  }

  String formatDateTime(DateTime dateTime, {String? pattern}) {
    final locale = currentLocale.toString();
    if (pattern != null) {
      return DateFormat(pattern, locale).format(dateTime);
    }
    return DateFormat.yMMMd(locale).add_Hm().format(dateTime);
  }

  String formatCurrency(double amount, {String? symbol}) {
    final locale = currentLocale.toString();
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol ?? getCurrencySymbol(),
    ).format(amount);
  }

  String getCurrencySymbol() {
    switch (currentLocale.languageCode) {
      case 'es':
      case 'fr':
      case 'de':
        return '€';
      case 'ja':
        return '¥';
      case 'bn':
        return '৳';
      default:
        return '\$';
    }
  }
}

final localizationServiceProvider = Provider<LocalizationService>((ref) {
  return LocalizationService(ref);
});

extension LocalizationServiceExtension on BuildContext {
  LocalizationService get localization =>
      ProviderScope.containerOf(this).read(localizationServiceProvider);

  Future<void> setLocale(Locale locale) => localization.setLocale(locale);

  Future<void> resetToSystemLocale() => localization.resetToSystemLocale();

  Locale get currentLocale => localization.currentLocale;

  String formatDate(DateTime date, {String? pattern}) =>
      localization.formatDate(date, pattern: pattern);

  String formatTime(DateTime time, {String? pattern}) =>
      localization.formatTime(time, pattern: pattern);

  String formatDateTime(DateTime dateTime, {String? pattern}) =>
      localization.formatDateTime(dateTime, pattern: pattern);

  String formatCurrency(double amount, {String? symbol}) =>
      localization.formatCurrency(amount, symbol: symbol);
}
