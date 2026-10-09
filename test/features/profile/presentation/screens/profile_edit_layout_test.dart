import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/repositories/profile_repository.dart';
import 'package:chatix/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:chatix/features/profile/presentation/screens/profile_edit_screen.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_photo_editor.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

import '../../../../helpers/pane_frame.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: _me, username: 'ada', email: 'ada@example.com');
}

/// An upload that is wherever the test needs it to be.
class _FakeUpload extends AvatarUploadController {
  _FakeUpload({this.stage, this.failure});

  final AvatarUploadStage? stage;
  final Failure? failure;

  @override
  Future<AvatarUploadStage?> build() async {
    final error = failure;
    if (error != null) throw error;
    return stage;
  }
}

const int _me = 42;

/// Editing one's profile opens, as in Telegram, on one's own face with the
/// way to change it underneath — and keeps the form to a column on a wide
/// pane.
void main() {
  final l10n = AppLocalizationsEn();

  late _MockProfileRepository profiles;

  ProfileEntity ada({Map<String, Map<String, String>> avatars = const {}}) =>
      ProfileEntity(
        id: _me,
        username: 'ada',
        avatars: avatars,
        specialization: 'Analytical engines',
        displayName: 'Ada Lovelace',
        bio: 'Writes the first programs for machines that do not exist yet.',
        dateBirthday: DateTime(1815, 12, 10),
        skills: const ['math'],
        contacts: const [],
      );

  setUp(() => profiles = _MockProfileRepository());

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    ProfileEntity? profile,
    _FakeUpload? upload,
    bool settle = true,
  }) async {
    final source = profile ?? ada();
    when(() => profiles.getMyProfile()).thenAnswer((_) async => Right(source));
    when(
      () => profiles.getProfile(any()),
    ).thenAnswer((_) async => Right(source));

    final router = GoRouter(
      initialLocation: '/profile',
      routes: [
        GoRoute(
          path: '/profile',
          builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
          routes: [
            GoRoute(path: 'edit', builder: (_, _) => const ProfileEditScreen()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_FakeAuthController.new),
          profileRepositoryProvider.overrideWithValue(profiles),
          if (upload != null) avatarUploadProvider.overrideWith(() => upload),
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

    router.push('/profile/edit');
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A spinner never settles.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }
  }

  Finder face() => find.descendant(
    of: find.byType(ProfilePhotoEditor),
    matching: find.byType(ChatAvatar),
  );

  Finder link(String label) => find.widgetWithText(TextButton, label);

  group('the photo at the top', () {
    testWidgets('is the profile face, round and centred over the form', (
      tester,
    ) async {
      await pump(tester);

      final circle = find
          .descendant(of: face(), matching: find.byType(ClipPath))
          .first;
      expect(tester.getSize(circle), Size.square(ChatAvatarSize.xxl.diameter));
      expect(
        tester.getCenter(circle).dx,
        moreOrLessEquals(PaneWindow.phone.size.width / 2, epsilon: 1),
      );
      // Above the first field, as in Telegram.
      expect(
        tester.getRect(circle).bottom,
        lessThan(tester.getTopLeft(find.text(l10n.profileEditDetails)).dy),
      );
    });

    testWidgets('offers to set one when there is none', (tester) async {
      await pump(tester);

      expect(link(l10n.setPhoto), findsOneWidget);
      expect(link(l10n.changePhoto), findsNothing);
    });

    testWidgets('offers to change it when there is one', (tester) async {
      await pump(
        tester,
        profile: ada(
          avatars: const {
            '256': {'webp': 'https://cdn.example.com/ada.webp'},
          },
        ),
      );

      expect(link(l10n.changePhoto), findsOneWidget);
    });

    testWidgets('tapping the face starts the same flow as the link', (
      tester,
    ) async {
      await pump(tester);

      await tester.tap(face());
      await tester.pumpAndSettle();

      expect(find.text(l10n.choosePhoto), findsOneWidget);
      expect(find.text(l10n.camera), findsOneWidget);
    });

    testWidgets('so does the link', (tester) async {
      await pump(tester);

      await tester.tap(link(l10n.setPhoto));
      await tester.pumpAndSettle();

      expect(find.text(l10n.choosePhoto), findsOneWidget);
    });
  });

  group('while a picture is on its way', () {
    testWidgets('the face dims under a spinner and cannot be tapped', (
      tester,
    ) async {
      await pump(
        tester,
        upload: _FakeUpload(stage: AvatarUploadStage.uploading),
        settle: false,
      );

      expect(
        find.descendant(
          of: find.byType(ProfilePhotoEditor),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextButton>(link(l10n.setPhoto)).onPressed, isNull);
      expect(find.text(l10n.avatarStageUploading), findsOneWidget);

      await tester.tap(face(), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.choosePhoto), findsNothing);
    });

    testWidgets('the server processing it still counts', (tester) async {
      await pump(
        tester,
        upload: _FakeUpload(stage: AvatarUploadStage.processing),
        settle: false,
      );

      expect(tester.widget<TextButton>(link(l10n.setPhoto)).onPressed, isNull);
      expect(find.text(l10n.avatarStageProcessing), findsOneWidget);
    });

    testWidgets('a picture the server refused frees the link again', (
      tester,
    ) async {
      await pump(
        tester,
        upload: _FakeUpload(failure: const AvatarProcessingFailure()),
      );

      expect(
        tester.widget<TextButton>(link(l10n.setPhoto)).onPressed,
        isNotNull,
      );
      expect(find.text(l10n.avatarProcessingFailed), findsOneWidget);
    });
  });

  testWidgets('on a desktop the form is a centred column', (tester) async {
    await pump(tester, window: PaneWindow.desktop);

    final form = tester.getRect(find.byType(Form));
    final paneLeft =
        PaneWindow.desktop.size.width - PaneWindow.desktop.paneWidth;

    expect(form.width, AppContentWidths.form);
    expect(
      form.center.dx,
      moreOrLessEquals(paneLeft + PaneWindow.desktop.paneWidth / 2, epsilon: 1),
    );
    expect(
      tester.getCenter(face()).dx,
      moreOrLessEquals(form.center.dx, epsilon: 1),
    );
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('edit profile, ${window.name}, ${theme.key}', (
          tester,
        ) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'profile_edit_${window.name}_${theme.key}',
          );
        });
      }
    }

    for (final theme in {'light': false, 'dark': true}.entries) {
      testGoldens('edit profile while uploading, ${theme.key}', (tester) async {
        await pump(
          tester,
          dark: theme.value,
          upload: _FakeUpload(stage: AvatarUploadStage.uploading),
          settle: false,
        );

        await screenMatchesGolden(
          tester,
          'profile_edit_uploading_${theme.key}',
          customPump: (tester) =>
              tester.pump(const Duration(milliseconds: 300)),
        );
      });
    }
  });
}
