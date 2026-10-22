import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_page_transitions.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/router/settings_pane_shell.dart';
import 'package:chatix/core/settings/dev_menu.dart';
import 'package:chatix/core/settings/send_shortcut.dart';
import 'package:chatix/core/storage/cache/attachment_cache_usage.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_badge_provider.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/settings/presentation/providers/about_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import 'pane_frame.dart';

/// The signed-in reader of the settings tests.
const int kSettingsMe = 7;

const UserEntity kSettingsUser = UserEntity(
  id: kSettingsMe,
  username: 'maria',
  email: 'maria@example.com',
);

const ProfileEntity kSettingsProfile = ProfileEntity(
  id: kSettingsMe,
  username: 'maria',
  avatars: {},
  specialization: null,
  displayName: 'Мария Иванова',
  bio: null,
  dateBirthday: null,
  skills: [],
  contacts: [],
);

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async => kSettingsUser;
}

class _FakeNotificationBadge extends NotificationBadgeController {
  _FakeNotificationBadge(this._count);

  final int _count;

  @override
  int build() => _count;
}

/// What a stub page says, so a test can tell which route it landed on.
String settingsStubLabel(String location) => 'stub:$location';

/// Mounts settings the way the shell does: [SettingsPaneShell] over a
/// navigator holding `/settings` and its sections, inside the rail (and,
/// on a desktop, beside the list it draws itself).
///
/// Sections are stubs that print their location unless [screens] gives a
/// real one, so a tap on a row can be followed without building every
/// screen behind it.
class SettingsHarness {
  SettingsHarness({
    this.profile = kSettingsProfile,
    this.profileFuture,
    this.alerts = 0,
    this.developer = false,
    this.cacheUsage = 0,
    this.version = const AppVersion(version: '1.0.0', build: '1'),
    this.links = const {},
    this.screens = const {},
  });

  /// What `GET /profiles/my/` answers. Ignored when [profileFuture] is set.
  final ProfileEntity profile;

  /// A profile that has not arrived yet, for the card's loading state.
  final Future<ProfileEntity>? profileFuture;

  final int alerts;
  final bool developer;
  final int cacheUsage;
  final AppVersion version;
  final Map<AboutLink, Uri> links;

  /// Real screens by location; anything else is a stub.
  final Map<String, Widget> screens;

  late ProviderContainer container;
  late GoRouter router;
  late SharedPreferences prefs;
  int cleared = 0;

  Widget _page(String location) =>
      screens[location] ??
      Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(settingsStubLabel(location))),
      );

  GoRoute _stub(String path, String location) =>
      GoRoute(path: path, builder: (_, _) => _page(location));

  /// A section the way the app's router builds one: no back arrow beside
  /// the list.
  GoRoute _section(String path, String location, {List<RouteBase>? routes}) =>
      GoRoute(
        path: path,
        pageBuilder: (context, state) => AppPageTransitions.section<void>(
          key: state.pageKey,
          besideList: AppLayoutScope.of(context).isTwoPane,
          child: _page(location),
        ),
        routes: routes ?? const [],
      );

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    String initialLocation = SettingsRoute.location,
    Size? surface,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        sendShortcutStoreProvider.overrideWithValue(
          InMemorySendShortcutStore(),
        ),
        authProvider.overrideWith(_FakeAuthController.new),
        profileDetailProvider(
          kSettingsMe,
        ).overrideWith((ref) => profileFuture ?? Future.value(profile)),
        notificationBadgeProvider.overrideWith(
          () => _FakeNotificationBadge(alerts),
        ),
        devMenuStoreProvider.overrideWithValue(InMemoryDevMenuStore(developer)),
        // The real one walks a cache directory the test platform has no
        // plugin for.
        attachmentCacheUsageProvider.overrideWith((ref) async => cacheUsage),
        clearAttachmentCacheProvider.overrideWithValue(() async {
          cleared++;
          return cacheUsage;
        }),
        appVersionProvider.overrideWith((ref) async => version),
        aboutLinksProvider.overrideWithValue(links),
      ],
    );
    addTearDown(container.dispose);

    router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (context, state, child) => PaneFrame(
            window: window,
            listStub: false,
            child: SettingsPaneShell(location: state.uri.path, child: child),
          ),
          routes: [
            GoRoute(
              path: SettingsRoute.path,
              builder: (_, _) =>
                  screens[SettingsRoute.location] ?? const SettingsHomePane(),
              routes: [
                _section(
                  NotificationSettingsRoute.path,
                  NotificationSettingsRoute.location,
                ),
                _section(
                  PrivacySettingsRoute.path,
                  PrivacySettingsRoute.location,
                  routes: [_stub(SessionsRoute.path, SessionsRoute.location)],
                ),
                _section(
                  DataStorageSettingsRoute.path,
                  DataStorageSettingsRoute.location,
                ),
                _section(
                  DevicesSettingsRoute.path,
                  DevicesSettingsRoute.location,
                ),
                _section(
                  AppearanceSettingsRoute.path,
                  AppearanceSettingsRoute.location,
                ),
                _section(
                  SettingsFoldersRoute.path,
                  SettingsFoldersRoute.location,
                ),
                _section(
                  LanguageSettingsRoute.path,
                  LanguageSettingsRoute.location,
                ),
                _section(AboutSettingsRoute.path, AboutSettingsRoute.location),
                _section(
                  DeveloperSettingsRoute.path,
                  DeveloperSettingsRoute.location,
                ),
              ],
            ),
            GoRoute(
              path: ProfileRoute.path,
              builder: (_, _) => _page(ProfileRoute.location),
              routes: [_stub(ProfileEditRoute.path, ProfileEditRoute.location)],
            ),
          ],
        ),
        _stub(NotificationsRoute.path, NotificationsRoute.location),
        _stub(ComponentShowcaseRoute.path, ComponentShowcaseRoute.location),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidgetBuilder(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: surface ?? window.size,
    );
    await tester.pumpAndSettle();
  }
}

/// Lets a pending future in [SettingsHarness.profileFuture] stay pending
/// for a test and still finish before it ends.
class PendingProfile {
  final Completer<ProfileEntity> _completer = Completer<ProfileEntity>();

  Future<ProfileEntity> get future => _completer.future;

  void complete([ProfileEntity profile = kSettingsProfile]) =>
      _completer.complete(profile);
}
