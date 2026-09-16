import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_update.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: me, username: 'ivan', email: 'ivan@example.com');
}

const int me = 7;

void main() {
  final l10n = AppLocalizationsEn();

  late MockProfileRepository profiles;

  final stored = ProfileEntity(
    id: me,
    avatars: const {},
    specialization: 'Backend engineer',
    displayName: 'Ivan Petrov',
    bio: 'Builds unglamorous things.',
    dateBirthday: DateTime(1990, 4, 12),
    skills: const ['dart'],
    contacts: const [],
  );

  setUpAll(() {
    registerFallbackValue(const ProfileUpdate());
  });

  setUp(() {
    profiles = MockProfileRepository();
    when(() => profiles.getMyProfile()).thenAnswer((_) async => Right(stored));
    when(
      () => profiles.updateProfile(any(), any()),
    ).thenAnswer((_) async => const Right(null));
  });

  Future<void> pump(WidgetTester tester, {ThemeData? theme}) async {
    // Pushed onto a route of its own, so there is a back button to press and
    // something to go back to.
    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          routes: [
            GoRoute(
              path: 'edit',
              builder: (_, _) => const ProfileEditScreen(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          profileRepositoryProvider.overrideWithValue(profiles),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: theme ?? AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    router.push('/profile/edit');
    await tester.pumpAndSettle();
  }

  /// The app bar's save, which is on screen whatever the form has scrolled
  /// to. The button at the bottom of the form does the same thing.
  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(TextButton, l10n.save));
    await tester.pumpAndSettle();
  }

  ProfileUpdate capturedUpdate() {
    return verify(() => profiles.updateProfile(me, captureAny())).captured.single
        as ProfileUpdate;
  }

  testWidgets('opens on what the profile already holds', (tester) async {
    await pump(tester);

    expect(find.text('Ivan Petrov'), findsOneWidget);
    expect(find.text('Backend engineer'), findsOneWidget);
    expect(find.text('Builds unglamorous things.'), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
  });

  testWidgets(
    'saving one edit still sends every other field (api-docs §4.4)',
    (tester) async {
      await pump(tester);

      await tester.enterText(
        find.widgetWithText(TextField, 'Ivan Petrov'),
        'Ivan P.',
      );
      await tester.pumpAndSettle();

      await save(tester);

      final update = capturedUpdate();

      // The PUT applies the body verbatim, so anything missing here would be
      // wiped on the server even though the user never touched it.
      expect(update.displayName, 'Ivan P.');
      expect(update.specialization, 'Backend engineer');
      expect(update.bio, 'Builds unglamorous things.');
      expect(update.skills, ['dart']);
      expect(update.dateBirthday, DateTime(1990, 4, 12));
    },
  );

  testWidgets('clearing a field sends it as an explicit null', (tester) async {
    await pump(tester);

    final bio = find.widgetWithText(TextField, 'Builds unglamorous things.');
    // ignore: avoid_print
    print('BIO MATCHES: ${bio.evaluate().length}');
    await tester.enterText(bio, '');
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('ERRORS: ${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).where((d) => d != null && d.contains('characters')).toList()}');

    await save(tester);

    final update = capturedUpdate();

    // Not an empty string: every screen that asks "is there a bio?" would
    // answer yes to one.
    expect(update.bio, isNull);
    expect(update.displayName, 'Ivan Petrov');
  });

  testWidgets('a display name cannot be typed past the server limit', (
    tester,
  ) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ivan Petrov'),
      'a' * 120,
    );
    await tester.pumpAndSettle();

    await save(tester);

    // 100 characters or more is TOO_LONG_DISPLAY_NAME (api-docs §2.5), so
    // the field stops at 99 rather than spending a request finding out.
    expect(capturedUpdate().displayName, 'a' * 99);
  });

  testWidgets('leaving with unsaved edits asks first', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, 'Ivan Petrov'),
      'Ivan P.',
    );
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(l10n.discardChangesTitle), findsOneWidget);
  });

  testWidgets('lays out in the dark theme without overflowing', (tester) async {
    await pump(tester, theme: AppTheme.dark());

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.profileEditLinks), findsOneWidget);
  });
}
