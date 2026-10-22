import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_photo.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_photos_provider.dart';
import 'package:chatix/features/profile/presentation/screens/profile_avatar_screen.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/features/profile/presentation/screens/username_profile_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/test_photos.dart';

const int _me = 7;
const int _other = 42;

class _Auth extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: _me, username: 'maria', email: 'm@example.com');
}

class _MockRepository extends Mock implements ProfileRepository {}

Map<String, Map<String, String>> _avatarsOf(int owner, String photoId) => {
  '512': {'webp': 'https://s3.example.com/profiles/$owner/$photoId/512.webp'},
};

ProfileEntity _profile(int id, {String? photoId = 'p3'}) => ProfileEntity(
  id: id,
  username: id == _me ? 'maria' : 'durov',
  avatars: photoId == null ? const {} : _avatarsOf(id, photoId),
  specialization: null,
  displayName: id == _me ? 'Мария Иванова' : 'Павел',
  bio: null,
  dateBirthday: null,
  skills: const [],
  contacts: const [],
);

List<ProfilePhoto> _history(int owner) => [
  for (final (index, id) in ['p3', 'p2', 'p1'].indexed)
    ProfilePhoto(
      id: id,
      avatars: _avatarsOf(owner, id),
      isMain: index == 0,
      createdAt: DateTime.utc(2026, 10, 20 - index * 9, 9),
    ),
];

/// The photos of a profile behind a real router: a list page to come from,
/// and the viewer pushed over it.
class _Harness {
  _Harness({required this.owner, List<ProfilePhoto>? photos})
    : photos = photos ?? _history(owner);

  final int owner;
  List<ProfilePhoto> photos;
  final _MockRepository repository = _MockRepository();
  late GoRouter router;

  String get _viewer => owner == _me
      ? ProfileAvatarRoute.location
      : ProfileDetailAvatarRoute.locationOf(owner);

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    List<Override> overrides = const [],
  }) async {
    when(() => repository.deletePhoto(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      photos = [
        for (final photo in photos)
          if (photo.id != id) photo,
      ];
      return const Right(null);
    });
    when(() => repository.setMainPhoto(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.single as String;
      final picked = photos.firstWhere((photo) => photo.id == id);
      photos = [
        picked,
        for (final photo in photos)
          if (photo.id != id) photo,
      ];
      return const Right(null);
    });

    final pictures = {
      for (final (index, id) in ['p1', 'p2', 'p3'].indexed)
        id: MemoryImage(TestPhotos.encode(480, 480, palette: index)),
    };

    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('profile')),
        ),
        GoRoute(
          path: ProfileAvatarRoute.location,
          builder: (_, _) => const ProfileAvatarScreen(),
        ),
        GoRoute(
          path: ProfileDetailAvatarRoute.locationOf(owner),
          builder: (_, _) => ProfileAvatarScreen(profileId: owner),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidgetBuilder(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          authProvider.overrideWith(_Auth.new),
          profileRepositoryProvider.overrideWithValue(repository),
          profileDetailProvider(
            owner,
          ).overrideWith((ref) async => _profile(owner)),
          profilePhotosProvider(owner).overrideWith((ref) async => photos),
          profilePhotoImageProvider.overrideWithValue(
            (url) => pictures[Uri.parse(url).pathSegments[2]]!,
          ),
          ...overrides,
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => AppClock(
            now: DateTime(2026, 10, 22, 12),
            child: PaneFrame(window: window, child: child!),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    await tester.pumpAndSettle();

    // Every picture into the image cache up front: a page swiped to then
    // draws at once rather than over a shimmering skeleton.
    final context = tester.element(find.text('profile'));
    await tester.runAsync(() async {
      for (final picture in pictures.values) {
        await precacheImage(picture, context);
      }
    });

    router.push(_viewer);
    // The skeleton under a photo still decoding shimmers for as long as it
    // is up, so the pictures are decoded before anything settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _decode(tester);
    await tester.pumpAndSettle();
  }

  /// Lets the in-memory pictures decode — that happens off the fake clock.
  Future<void> _decode(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
  }
}

void main() {
  final ru = AppLocalizationsRu();

  group('the photo viewer', () {
    testWidgets('opens on the current photo and counts the history', (
      tester,
    ) async {
      await _Harness(owner: _other).pump(tester);

      expect(find.text(ru.mediaViewerCounter(1, 3)), findsOneWidget);
      // The day the current photo went up.
      expect(find.text('20 октября'), findsOneWidget);
    });

    testWidgets('a swipe goes back in time', (tester) async {
      await _Harness(owner: _other).pump(tester);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();

      expect(find.text(ru.mediaViewerCounter(2, 3)), findsOneWidget);
      expect(find.text('11 октября'), findsOneWidget);
    });

    testWidgets('somebody else\'s photos offer nothing to change', (
      tester,
    ) async {
      await _Harness(owner: _other).pump(tester);

      expect(find.byTooltip(ru.profileActionMore), findsNothing);
    });

    testWidgets('a history the viewer may not see falls back to the face', (
      tester,
    ) async {
      // Hidden by the `photo` rule: the history is empty, but the profile
      // read before it still had a picture — show that one alone.
      await _Harness(owner: _other, photos: const []).pump(tester);

      expect(find.text(ru.profilePhoto), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('one\'s own old photo can be brought back to the front', (
      tester,
    ) async {
      final harness = _Harness(owner: _me);
      await harness.pump(tester);

      await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(ru.profileActionMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.profilePhotoMakeMain));
      await tester.pumpAndSettle();

      verify(() => harness.repository.setMainPhoto('p2')).called(1);
      expect(find.text(ru.profilePhotoMadeMain), findsOneWidget);
      expect(harness.photos.first.id, 'p2');
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('the current photo offers no "make main", only delete', (
      tester,
    ) async {
      await _Harness(owner: _me).pump(tester);

      await tester.tap(find.byTooltip(ru.profileActionMore));
      await tester.pumpAndSettle();

      expect(find.text(ru.profilePhotoMakeMain), findsNothing);
      expect(find.text(ru.profilePhotoDelete), findsOneWidget);
    });

    testWidgets('deleting asks first, and says the photo before takes over', (
      tester,
    ) async {
      final harness = _Harness(owner: _me);
      await harness.pump(tester);

      await tester.tap(find.byTooltip(ru.profileActionMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.profilePhotoDelete));
      await tester.pumpAndSettle();

      expect(find.text(ru.profilePhotoDeleteCurrentBody), findsOneWidget);
      await tester.tap(find.text(ru.cancel));
      await tester.pumpAndSettle();
      verifyNever(() => harness.repository.deletePhoto(any()));

      await tester.tap(find.byTooltip(ru.profileActionMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.profilePhotoDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(ru.profilePhotoDelete),
        ),
      );
      await tester.pumpAndSettle();

      verify(() => harness.repository.deletePhoto('p3')).called(1);
      expect(find.text(ru.profilePhotoDeleted), findsOneWidget);
      expect(find.text(ru.mediaViewerCounter(1, 2)), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a refusal is said in words', (tester) async {
      final harness = _Harness(owner: _me);
      await harness.pump(tester);
      when(() => harness.repository.deletePhoto(any())).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'NOT_FOUND_PROFILE_PHOTO',
            message: 'gone',
            detail: null,
            status: 404,
          ),
        ),
      );

      await tester.tap(find.byTooltip(ru.profileActionMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.profilePhotoDelete));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(ru.profilePhotoDelete),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(ru.apiErrorProfilePhotoNotFound), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    });
  });

  group('a profile link', () {
    Future<void> pumpLink(
      WidgetTester tester,
      String username, {
      required Future<ProfileEntity> Function() answer,
      PaneWindow window = PaneWindow.phone,
      bool dark = false,
    }) async {
      final router = GoRouter(
        initialLocation: UsernameProfileRoute.locationOf(username),
        routes: [
          GoRoute(
            path: UsernameProfileRoute.path,
            builder: (_, state) => UsernameProfileScreen(
              username: UsernameProfileRoute.usernameFrom(state)!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidgetBuilder(
        ProviderScope(
          retry: (_, _) => null,
          overrides: [
            authProvider.overrideWith(_Auth.new),
            profileByUsernameProvider(
              usernameKey(username),
            ).overrideWith((ref) => answer()),
            // The page the link hands over to: still loading, which is all
            // this test needs to see of it.
            profileDetailProvider(
              _other,
            ).overrideWith((ref) => Completer<ProfileEntity>().future),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            locale: const Locale('ru'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) =>
                PaneFrame(window: window, child: child!),
          ),
        ),
        wrapper: (child) => child,
        surfaceSize: window.size,
      );
      await tester.pump();
      await tester.pump();
    }

    Future<ProfileEntity> notFound() async => throw const ApiFailure(
      code: 'NOT_FOUND_PROFILE',
      message: 'not found',
      detail: {'username': 'ghost'},
      status: 404,
    );

    testWidgets('opens the profile of whoever has the handle', (tester) async {
      await pumpLink(tester, 'Durov', answer: () async => _profile(_other));

      final screen = tester.widget<ProfileScreen>(find.byType(ProfileScreen));
      expect(screen.profileId, _other);
    });

    testWidgets('says plainly when nobody has it', (tester) async {
      await pumpLink(tester, '@ghost', answer: notFound);
      await tester.pumpAndSettle();

      expect(find.text(ru.profileByUsernameNotFound('@ghost')), findsOneWidget);
      expect(find.text(ru.profileByUsernameNotFoundHint), findsOneWidget);
      expect(find.byType(ProfileScreen), findsNothing);
    });

    testWidgets('a failure to ask is not "nobody", and can be retried', (
      tester,
    ) async {
      await pumpLink(
        tester,
        'durov',
        answer: () async => throw const NetworkFailure(message: 'offline'),
      );
      await tester.pumpAndSettle();

      expect(find.text(ru.profileByUsernameNotFound('@durov')), findsNothing);
      expect(find.text(ru.retry), findsOneWidget);
    });

    group('goldens', () {
      for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
        for (final MapEntry(key: theme, value: dark) in {
          'light': false,
          'dark': true,
        }.entries) {
          testGoldens('not found, ${window.name}, $theme', (tester) async {
            await pumpLink(
              tester,
              'ghost',
              answer: notFound,
              window: window,
              dark: dark,
            );
            await tester.pumpAndSettle();
            await screenMatchesGolden(
              tester,
              'profile_link_not_found_${window.name}_$theme',
            );
          });
        }
      }
    });
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final MapEntry(key: theme, value: dark) in {
        'light': false,
        'dark': true,
      }.entries) {
        testGoldens('own photo history, ${window.name}, $theme', (
          tester,
        ) async {
          await _Harness(owner: _me).pump(tester, window: window, dark: dark);
          await screenMatchesGolden(
            tester,
            'profile_photos_${window.name}_$theme',
            customPump: (tester) async {},
          );
        });
      }
    }
  });
}
