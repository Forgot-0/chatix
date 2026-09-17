import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockAuthRepository extends Mock implements AuthRepository {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: me, username: 'ivan', email: 'ivan@example.com');
}

const int me = 7;
const int other = 42;

void main() {
  final l10n = AppLocalizationsEn();

  // The share link is built off the configured origin.
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late MockProfileRepository profiles;
  late MockAuthRepository auth;

  setUp(() {
    profiles = MockProfileRepository();
    auth = MockAuthRepository();

    when(() => auth.getMySessions()).thenAnswer(
      (_) async => Right<Failure, List<SessionEntity>>(const [
        SessionEntity(
          id: 1,
          userId: me,
          deviceInfo: 'Pixel 8',
          userAgent: 'chatix/1.0',
          lastActivity: null,
          isActive: true,
        ),
      ]),
    );
  });

  ProfileEntity profile({
    int id = other,
    String? displayName = 'Ivan Petrov',
    String? specialization = 'Backend engineer',
    String? bio = 'Builds unglamorous things that stay up.',
    List<String> skills = const ['dart', 'python'],
    List<ContactEntity> contacts = const [],
    DateTime? birthday,
  }) => ProfileEntity(
    id: id,
    avatars: const {},
    specialization: specialization,
    displayName: displayName,
    bio: bio,
    dateBirthday: birthday,
    skills: skills,
    contacts: contacts,
  );

  Future<void> pump(
    WidgetTester tester, {
    required ProfileEntity source,
    int? profileId,
    String? username,
    ThemeData? theme,
  }) async {
    when(() => profiles.getMyProfile()).thenAnswer((_) async => Right(source));
    when(
      () => profiles.getProfile(any()),
    ).thenAnswer((_) async => Right(source));

    final router = GoRouter(
      initialLocation: '/here',
      routes: [
        GoRoute(
          path: '/here',
          builder: (_, _) =>
              ProfileScreen(profileId: profileId, username: username),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          profileRepositoryProvider.overrideWithValue(profiles),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group("somebody else's profile", () {
    testWidgets('shows what the DTO carries', (tester) async {
      await pump(
        tester,
        profileId: other,
        source: profile(birthday: DateTime(1990, 4, 12)),
      );

      expect(find.text('Ivan Petrov'), findsOneWidget);
      expect(find.text('Backend engineer'), findsOneWidget);
      expect(
        find.text('Builds unglamorous things that stay up.'),
        findsOneWidget,
      );
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('python'), findsOneWidget);
      expect(find.text(l10n.profileBirthday), findsOneWidget);
    });

    testWidgets('offers message, call and share — never edit', (tester) async {
      await pump(tester, profileId: other, source: profile());

      expect(find.text(l10n.sendMessageAction), findsOneWidget);
      expect(find.text(l10n.callTitle), findsOneWidget);
      expect(find.text(l10n.profileShareAction), findsOneWidget);
      expect(find.text(l10n.editProfile), findsNothing);
    });

    testWidgets('has no account rows on it', (tester) async {
      await pump(tester, profileId: other, source: profile());

      expect(find.text(l10n.profileAccount), findsNothing);
      expect(find.text(l10n.myDevices), findsNothing);
    });

    testWidgets('shows the handle the route carried', (tester) async {
      // `ProfileDTO` has no username, so without this it cannot be shown at
      // all (api-docs §4.3 — see docs/BACKEND_GAPS.md).
      await pump(
        tester,
        profileId: other,
        username: 'ivan_dev',
        source: profile(),
      );

      expect(find.text('@ivan_dev'), findsOneWidget);
    });

    testWidgets('falls back to the handle when there is no name', (
      tester,
    ) async {
      await pump(
        tester,
        profileId: other,
        username: 'ivan_dev',
        source: profile(displayName: null),
      );

      expect(find.text('@ivan_dev'), findsOneWidget);
      expect(find.text(l10n.unknownProfile), findsNothing);
    });

    testWidgets('renders a link with its provider and its value', (
      tester,
    ) async {
      await pump(
        tester,
        profileId: other,
        source: profile(
          contacts: const [
            ContactEntity(
              profileId: other,
              provider: 'telegram',
              contact: '@ivan',
            ),
          ],
        ),
      );

      expect(find.text(l10n.profileContacts), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
      expect(find.text('@ivan'), findsOneWidget);
    });

    testWidgets('an empty profile says so rather than showing blanks', (
      tester,
    ) async {
      await pump(
        tester,
        profileId: other,
        source: profile(specialization: null, bio: null, skills: const []),
      );

      expect(find.text(l10n.profileEmptyHintOther), findsOneWidget);
      expect(find.text(l10n.profileAbout), findsNothing);
      expect(find.text(l10n.profileSkills), findsNothing);
    });
  });

  group('my own profile', () {
    testWidgets('offers edit and share, not message or call', (tester) async {
      await pump(tester, source: profile(id: me));

      expect(find.text(l10n.editProfile), findsWidgets);
      expect(find.text(l10n.profileShareAction), findsOneWidget);
      expect(find.text(l10n.sendMessageAction), findsNothing);
      expect(find.text(l10n.callTitle), findsNothing);
    });

    testWidgets('carries the account, settings and devices rows', (
      tester,
    ) async {
      await pump(tester, source: profile(id: me));

      expect(find.text(l10n.profileAccount), findsOneWidget);
      // The handle and address come from GET /users/me/, which is the only
      // place either of them exists (api-docs §3.9).
      expect(find.text('@ivan · ivan@example.com'), findsOneWidget);
      expect(find.text(l10n.settings), findsOneWidget);
      expect(find.text(l10n.myDevices), findsOneWidget);
      // `GET /users/sessions/` is a bare array, so the count is its length.
      expect(find.text(l10n.devicesCount(1)), findsOneWidget);
    });

    testWidgets('lays out in the dark theme without overflowing', (
      tester,
    ) async {
      await pump(
        tester,
        source: profile(id: me, birthday: DateTime(1990, 4, 12)),
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Ivan Petrov'), findsOneWidget);
    });
  });
}
