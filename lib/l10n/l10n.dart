import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';

import 'app_localizations_delegate.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
    Locale('ja'),
    Locale('bn'),
  ];

  static bool isSupported(Locale locale) {
    return supportedLocales.contains(Locale(locale.languageCode));
  }

  String translate(String key) {
    final languageMap = localizedValues[locale.languageCode];
    if (languageMap == null) {
      return localizedValues['en']?[key] ?? key;
    }
    return languageMap[key] ?? localizedValues['en']?[key] ?? key;
  }

  String translateWithParams(String key, Map<String, String> params) {
    String value = translate(key);
    params.forEach((paramKey, paramValue) {
      value = value.replaceAll('{$paramKey}', paramValue);
    });
    return value;
  }

  String formatCurrency(double amount) {
    return NumberFormat.currency(
      locale: locale.toString(),
      symbol: getCurrencySymbol(),
    ).format(amount);
  }

  String formatDate(DateTime date) {
    return DateFormat.yMMMd(locale.toString()).format(date);
  }

  String formatTime(DateTime time) {
    return DateFormat.Hm(locale.toString()).format(time);
  }

  String getCurrencySymbol() {
    switch (locale.languageCode) {
      case 'es':
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

final Map<String, Map<String, String>> localizedValues = {
  'en': {
    'app_title': 'Flutter Riverpod Clean Architecture',
    'welcome_message': 'Welcome to Flutter Riverpod Clean Architecture',
    'home': 'Home',
    'settings': 'Settings',
    'profile': 'Profile',
    'dark_mode': 'Dark Mode',
    'light_mode': 'Light Mode',
    'system_mode': 'System Mode',
    'language': 'Language',
    'logout': 'Logout',
    'login': 'Login',
    'email': 'Email',
    'password': 'Password',
    'sign_in': 'Sign In',
    'register': 'Register',
    'forgot_password': 'Forgot Password?',
    'error_occurred': 'An error occurred',
    'try_again': 'Try Again',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'no_data': 'No data available',
    'loading': 'Loading...',
    'cache_expired': 'Cache has expired',
    'cache_updated': 'Cache updated successfully',
  },
  'es': {
    'app_title': 'Flutter Riverpod Arquitectura Limpia',
    'welcome_message': 'Bienvenido a Flutter Riverpod Arquitectura Limpia',
    'home': 'Inicio',
    'settings': 'Configuraciones',
    'profile': 'Perfil',
    'dark_mode': 'Modo Oscuro',
    'light_mode': 'Modo Claro',
    'system_mode': 'Modo Sistema',
    'language': 'Idioma',
    'logout': 'Cerrar Sesión',
    'login': 'Iniciar Sesión',
    'email': 'Correo Electrónico',
    'password': 'Contraseña',
    'sign_in': 'Iniciar Sesión',
    'register': 'Registrarse',
    'forgot_password': '¿Olvidó su Contraseña?',
    'error_occurred': 'Ocurrió un error',
    'try_again': 'Intentar de nuevo',
    'cancel': 'Cancelar',
    'save': 'Guardar',
    'delete': 'Eliminar',
    'edit': 'Editar',
    'no_data': 'No hay datos disponibles',
    'loading': 'Cargando...',
    'cache_expired': 'El caché ha expirado',
    'cache_updated': 'Caché actualizado con éxito',
  },
  'fr': {
    'app_title': 'Flutter Riverpod Architecture Propre',
    'welcome_message': 'Bienvenue à Flutter Riverpod Architecture Propre',
  },
};

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  String tr(String key) => l10n.translate(key);

  String trParams(String key, Map<String, String> params) =>
      l10n.translateWithParams(key, params);

  String currency(double amount) => l10n.formatCurrency(amount);

  String formatDate(DateTime date) => l10n.formatDate(date);

  String formatTime(DateTime time) => l10n.formatTime(time);
}
