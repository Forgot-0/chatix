import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pane_frame.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: _me, username: 'me', email: 'me@example.com');
}

const int _me = 7;
const int _other = 42;

/// Where the profile header puts the face, in every window the profile can
/// be opened in.
///
/// The header used to centre the avatar on the window while the name was
/// centred on the pane, so beside a rail and a chat list the face sat a
/// list's width to the right of the name it belongs to.
void main() {
  setUpAll(
    () => dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com'),
  );

  late _MockProfileRepository profiles;
  late _MockAuthRepository auth;

  setUp(() {
    profiles = _MockProfileRepository();
    auth = _MockAuthRepository();

    when(
      () => auth.getMySessions(),
    ).thenAnswer((_) async => const Right<Failure, List<SessionEntity>>([]));
  });

  const ada = ProfileEntity(
    id: _other,
    username: 'ada',
    avatars: {},
    specialization: 'Analytical engines',
    displayName: 'Ada Lovelace',
    bio: 'Writes the first programs for machines that do not exist yet.',
    dateBirthday: null,
    skills: ['math', 'poetry'],
    contacts: [],
  );

  Future<void> pump(
    WidgetTester tester, {
    required PaneWindow window,
    bool dark = false,
  }) async {
    when(() => profiles.getMyProfile()).thenAnswer((_) async => right(ada));
    when(() => profiles.getProfile(any())).thenAnswer((_) async => right(ada));

    final router = GoRouter(
      initialLocation: '/here',
      routes: [
        GoRoute(
          path: '/here',
          builder: (_, _) => const ProfileScreen(profileId: _other),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          profileRepositoryProvider.overrideWithValue(profiles),
          authRepositoryProvider.overrideWithValue(auth),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: router,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => PaneFrame(window: window, child: child!),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();
  }

  Finder avatar() =>
      find.descendant(of: find.byType(Hero), matching: find.byType(ChatAvatar));

  group('the face sits over the name', () {
    for (final window in PaneWindow.values) {
      testWidgets('in a ${window.paneWidth.round()} px pane (${window.name})', (
        tester,
      ) async {
        await pump(tester, window: window);

        final face = tester.getCenter(avatar());
        final name = tester.getCenter(find.text('Ada Lovelace'));

        expect(face.dx, moreOrLessEquals(name.dx, epsilon: 1));

        // And both are in the middle of the pane, not of the window.
        final paneLeft = window.size.width - window.paneWidth;
        expect(
          face.dx,
          moreOrLessEquals(paneLeft + window.paneWidth / 2, epsilon: 1),
        );
      });
    }

    testWidgets('and is drawn at the profile size, round', (tester) async {
      await pump(tester, window: PaneWindow.desktop);

      expect(
        tester.getSize(avatar()),
        Size.square(ChatAvatarSize.xxl.diameter),
      );
    });
  });

  group('goldens', () {
    for (final window in PaneWindow.values) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('profile, ${window.name}, ${theme.key}', (tester) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'profile_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
