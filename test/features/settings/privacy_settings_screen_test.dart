import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/auth/app_lock_store.dart';
import 'package:chatix/core/auth/biometric_providers.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../helpers/pane_frame.dart';

SessionEntity _session(int id, String device, {bool active = true}) =>
    SessionEntity(
      id: id,
      userId: 7,
      deviceInfo: device,
      userAgent: '',
      lastActivity: DateTime(2026, 10, 11, 9),
      isActive: active,
    );

/// Settings → Privacy: the block list, the devices and the app lock — and
/// nothing the API cannot back.
void main() {
  final ru = AppLocalizationsRu();

  List<Override> overrides({
    Set<int>? blocked = const {42, 43, 44},
    bool biometricsOn = true,
  }) => [
    blockListLocalStoreProvider.overrideWithValue(
      MemoryBlockListLocalStore(
        blocked == null ? null : BlockList(ownerId: 7, userIds: blocked),
      ),
    ),
    mySessionsProvider.overrideWith(
      (ref) async => [
        _session(1, 'Pixel 9 · Android 17'),
        _session(2, 'Windows 11 · ChatiX desktop'),
      ],
    ),
    appLockStoreProvider.overrideWithValue(
      InMemoryAppLockStore(enabled: biometricsOn),
    ),
    biometricsAvailableProvider.overrideWith((ref) async => true),
  ];

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    Set<int>? blocked = const {42, 43, 44},
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        retry: (_, _) => null,
        overrides: overrides(blocked: blocked),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(window: window, child: const PrivacySettingsScreen()),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
  }

  testWidgets('three things, each saying where it stands', (tester) async {
    await pump(tester);

    expect(find.text(ru.blockedUsersTitle), findsOneWidget);
    expect(find.text(ru.blockedUsersCount(3)), findsOneWidget);
    expect(find.text(ru.privacyDevices), findsOneWidget);
    expect(find.text(ru.devicesCount(2)), findsOneWidget);
    expect(find.text(ru.privacyPasscodeSection), findsOneWidget);
    expect(find.text(ru.biometricUnlockTitle), findsOneWidget);
    expect(find.text(ru.privacyPasscodeNote), findsOneWidget);
  });

  testWidgets('nothing stored yet: no count rather than a wrong one', (
    tester,
  ) async {
    await pump(tester, blocked: null);

    expect(find.text(ru.blockedUsersTitle), findsOneWidget);
    expect(find.text(ru.blockedUsersCount(0)), findsNothing);
  });

  testWidgets('nobody blocked says so', (tester) async {
    await pump(tester, blocked: const {});

    expect(find.text(ru.blockedUsersCount(0)), findsOneWidget);
  });

  group('where the rows lead', () {
    Future<void> pumpRouted(WidgetTester tester) async {
      Widget stub(String label) => Scaffold(body: Center(child: Text(label)));

      final router = GoRouter(
        initialLocation: PrivacySettingsRoute.location,
        routes: [
          GoRoute(
            path: SettingsRoute.path,
            builder: (_, _) => stub('settings'),
            routes: [
              GoRoute(
                path: PrivacySettingsRoute.path,
                builder: (_, _) => const PrivacySettingsScreen(),
                routes: [
                  GoRoute(
                    path: BlockedUsersRoute.path,
                    builder: (_, _) => stub('blocked list'),
                  ),
                  GoRoute(
                    path: SessionsRoute.path,
                    builder: (_, _) => stub('devices'),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          retry: (_, _) => null,
          overrides: overrides(),
          child: MaterialApp.router(
            routerConfig: router,
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('"Blocked users" opens the block list', (tester) async {
      await pumpRouted(tester);

      await tester.tap(find.text(ru.blockedUsersTitle));
      await tester.pumpAndSettle();

      expect(find.text('blocked list'), findsOneWidget);
    });

    testWidgets('"Devices" opens the sessions, now under Privacy', (
      tester,
    ) async {
      await pumpRouted(tester);

      await tester.tap(find.text(ru.privacyDevices));
      await tester.pumpAndSettle();

      expect(find.text('devices'), findsOneWidget);
      expect(SessionsRoute.location, '/settings/privacy/devices');
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('privacy, ${window.name}, ${theme.key}', (tester) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'privacy_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
