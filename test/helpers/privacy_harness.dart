import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/auth/app_lock_providers.dart';
import 'package:chatix/core/auth/app_lock_store.dart';
import 'package:chatix/core/auth/biometric_providers.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/router/app_page_transitions.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/key_value_table.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/data/datasources/block_list_local_store.dart';
import 'package:chatix/features/contacts/data/datasources/contacts_local_store.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/settings/data/repositories/privacy_repository_impl.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/domain/repositories/privacy_repository.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_exceptions_screen.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_people_picker_screen.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_rule_screen.dart';
import 'package:chatix/features/settings/presentation/screens/privacy_settings_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import 'contacts_fixtures.dart';
import 'pane_frame.dart';

/// `PUT /profiles/privacy/` as the server would answer it, kept in memory
/// and recorded.
class FakePrivacyRepository implements PrivacyRepository {
  FakePrivacyRepository([this.settings = PrivacySettings.defaults]);

  PrivacySettings settings;

  /// Every update sent, in order.
  final List<
    ({
      Map<PrivacyRule, PrivacyVisibility> rules,
      Map<PrivacyRule, PrivacyExceptions> exceptions,
    })
  >
  updates = [];

  /// Answered once by the next update instead of applying it.
  Failure? failNext;

  /// When set, `GET` fails with it.
  Failure? failGet;

  @override
  Future<Either<Failure, PrivacySettings>> get() async {
    final failure = failGet;
    return failure == null ? Right(settings) : Left(failure);
  }

  @override
  Future<Either<Failure, PrivacySettings>> update({
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  }) async {
    updates.add((rules: rules, exceptions: exceptions));
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      return Left(failure);
    }
    var next = settings;
    for (final MapEntry(key: rule, value: visibility) in rules.entries) {
      next = next.withVisibility(rule, visibility);
    }
    for (final MapEntry(key: rule, value: lists) in exceptions.entries) {
      next = next.withExceptions(rule, lists);
    }
    settings = next;
    return Right(next);
  }
}

class _FakeAuth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: kOwnerId, username: 'maria', email: 'm@example.com');
}

/// The address book the privacy tests pick people from.
final List<Contact> kPrivacyBook = [
  contact(1, displayName: 'Анна Смирнова', username: 'anna'),
  contact(2, displayName: 'Борис Петров', username: 'boris'),
  contact(3, displayName: 'Вера Ким', username: 'vera'),
];

/// Somebody who is not in the book: their name comes from their profile.
ProfileEntity strangerProfile(int id, String username, [String? name]) =>
    ProfileEntity(
      id: id,
      username: username,
      avatars: const {},
      specialization: null,
      displayName: name,
      bio: null,
      dateBirthday: null,
      skills: const [],
      contacts: const [],
    );

/// Settings → Privacy and everything under it, behind a real router, over
/// a fake server and a scripted address book.
class PrivacyHarness {
  PrivacyHarness({
    PrivacySettings settings = PrivacySettings.defaults,
    this.book,
    this.strangers = const [],
  }) : repository = FakePrivacyRepository(settings);

  final FakePrivacyRepository repository;
  final List<Contact>? book;

  /// People on the lists who are not in the book.
  final List<ProfileEntity> strangers;

  late ProviderContainer container;
  late GoRouter router;

  Page<void> _section(BuildContext context, GoRouterState state, Widget w) =>
      AppPageTransitions.section<void>(
        key: state.pageKey,
        besideList: AppLayoutScope.of(context).isTwoPane,
        child: w,
      );

  Future<void> pump(
    WidgetTester tester, {
    String location = PrivacySettingsRoute.location,
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    Size? surface,
  }) async {
    final store = KeyValueContactsLocalStore(MemoryKeyValueTable());
    await tester.runAsync(
      () => store.save(
        ContactsSnapshot(
          ownerId: kOwnerId,
          contacts: book ?? kPrivacyBook,
          version: 'v1',
        ),
      ),
    );

    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        privacyRepositoryProvider.overrideWithValue(repository),
        contactsLocalStoreProvider.overrideWithValue(store),
        directChatIdsProvider.overrideWithValue(const {}),
        blockListLocalStoreProvider.overrideWithValue(
          MemoryBlockListLocalStore(
            const BlockList(ownerId: kOwnerId, userIds: {42}),
          ),
        ),
        mySessionsProvider.overrideWith(
          (ref) async => [
            SessionEntity(
              id: 1,
              userId: kOwnerId,
              deviceInfo: 'Pixel 9',
              userAgent: '',
              lastActivity: DateTime(2026, 10, 22, 9),
              isActive: true,
            ),
          ],
        ),
        appLockStoreProvider.overrideWithValue(InMemoryAppLockStore()),
        biometricsAvailableProvider.overrideWith((ref) async => true),
        for (final profile in strangers)
          profileDetailProvider(
            profile.id,
          ).overrideWith((ref) async => profile),
      ],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() => container.read(authProvider.future));

    router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              PaneFrame(window: window, child: child),
          routes: [
            GoRoute(
              path: SettingsRoute.path,
              builder: (_, _) => const Scaffold(body: Text('settings')),
              routes: [
                GoRoute(
                  path: PrivacySettingsRoute.path,
                  pageBuilder: (context, state) =>
                      _section(context, state, const PrivacySettingsScreen()),
                  routes: [
                    GoRoute(
                      path: BlockedUsersRoute.path,
                      builder: (_, _) => const Scaffold(body: Text('blocked')),
                    ),
                    GoRoute(
                      path: SessionsRoute.path,
                      builder: (_, _) => const Scaffold(body: Text('devices')),
                    ),
                    GoRoute(
                      path: PrivacyRuleRoute.path,
                      builder: (_, state) => PrivacyRuleScreen(
                        rule: PrivacyRule.fromSlug(
                          PrivacyRuleRoute.slugFrom(state),
                        )!,
                      ),
                      routes: [
                        GoRoute(
                          path: PrivacyExceptionsRoute.path,
                          builder: (_, state) => PrivacyExceptionsScreen(
                            rule: PrivacyRule.fromSlug(
                              PrivacyRuleRoute.slugFrom(state),
                            )!,
                            kind: PrivacyExceptionKind.fromSlug(
                              PrivacyExceptionsRoute.slugFrom(state),
                            )!,
                          ),
                          routes: [
                            GoRoute(
                              path: PrivacyExceptionsEditRoute.path,
                              builder: (_, state) => PrivacyPeoplePickerScreen(
                                rule: PrivacyRule.fromSlug(
                                  PrivacyRuleRoute.slugFrom(state),
                                )!,
                                kind: PrivacyExceptionKind.fromSlug(
                                  PrivacyExceptionsRoute.slugFrom(state),
                                )!,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
