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
import 'package:chatix/core/providers/theme_providers.dart';
import 'package:chatix/core/router/app_router.dart';
import 'package:chatix/core/ui/widgets/app_text_scale.dart';
import 'package:chatix/core/updates/update_providers.dart';
import 'package:chatix/features/chat/data/datasources/chat_local_data_source.dart';
import 'package:chatix/features/chat/data/datasources/hive_chat_local_store.dart';
import 'package:chatix/features/chat/presentation/providers/chat_cache_lifecycle_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/call_mini_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart' as arb;
import 'package:chatix/l10n/app_localizations_delegate.dart';
import 'package:chatix/l10n/l10n.dart';
import 'package:hive/hive.dart';
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

  // Both the chat store and the offline sync queue are Hive boxes, and Hive
  // has to be told where to put them before either can be opened.
  Hive.init('${appDir.path}/hive');

  // Opened here rather than lazily so that the first frame can already be
  // drawn from it: a chat screen reads the cache synchronously, which is
  // what makes reopening the app a frame instead of a request.
  final chatStore = await openHiveChatLocalStore();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        cookieJarProvider.overrideWithValue(cookieJar),
        chatLocalDataSourceProvider.overrideWithValue(chatStore),

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

    final textScale = ref.watch(textScaleProvider);

    final locale = ref.watch(persistentLocaleProvider);

    ref.watch(chatSocketLifecycleProvider);
    ref.watch(chatCacheLifecycleProvider);

    return UpdateChecker(
      autoPrompt: true,
      enforceCriticalUpdates: true,
      child: AccessibilityWrapper(
        child: MaterialApp.router(
          title: AppConstants.appName,
          theme: ref.watch(lightThemeProvider),
          darkTheme: ref.watch(darkThemeProvider),
          themeMode: themeMode,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          // The mini player is mounted above the router, not inside a route,
          // so a live call keeps a window on itself through every navigation.
          builder: (context, child) => AppTextScale(
            scale: textScale,
            child: CallOverlay(child: child ?? const SizedBox.shrink()),
          ),

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
