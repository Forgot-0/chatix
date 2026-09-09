import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:chatix/core/accessibility/accessibility_providers.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/providers/localization_providers.dart';
import 'package:chatix/core/providers/network_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/chat_density_provider.dart';
import 'package:chatix/core/theme/theme_mode_provider.dart';
import 'package:chatix/core/updates/update_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart' as arb;
import 'package:chatix/l10n/app_localizations_delegate.dart';
import 'package:chatix/l10n/l10n.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final sharedPreferences = await SharedPreferences.getInstance();
  CookieJar cookieJar;

  final appDir = await getApplicationDocumentsDirectory();
  cookieJar = PersistCookieJar(
    storage: FileStorage('${appDir.path}/.cookies/'),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        cookieJarProvider.overrideWithValue(cookieJar),

        defaultLocaleProvider.overrideWith(
          (ref) => ref.watch(persistentLocaleProvider),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    final themeMode = ref.watch(themeModeProvider);

    final density = ref.watch(chatDensityProvider);

    final locale = ref.watch(persistentLocaleProvider);

    ref.watch(chatSocketLifecycleProvider);

    return UpdateChecker(
      autoPrompt: true,
      enforceCriticalUpdates: true,
      child: AccessibilityWrapper(
        child: MaterialApp.router(
          title: AppConstants.appName,
          theme: AppTheme.light(density),
          darkTheme: AppTheme.dark(density),
          themeMode: themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,

          locale: locale,
          localizationsDelegates: [
            const AppLocalizationsDelegate(),
            arb.AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
  }
}
