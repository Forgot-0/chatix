import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/models/page_result.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/usecases/get_profiles_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_providers.dart';
import 'package:chatix/features/profile/presentation/screens/profiles_list_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pane_frame.dart';

class _MockGetProfilesUseCase extends Mock implements GetProfilesUseCase {}

/// The contacts list draws people the way every other screen does: the
/// same circle, the same colour for the same person.
void main() {
  ProfileEntity person(int id, String username, [String? displayName]) =>
      ProfileEntity(
        id: id,
        username: username,
        avatars: const {},
        specialization: null,
        displayName: displayName,
        bio: null,
        dateBirthday: null,
        skills: const [],
        contacts: const [],
      );

  final people = [
    person(42, 'ada', 'Ada Lovelace'),
    person(43, 'grace', 'Grace Hopper'),
    person(44, 'linus', 'Linus Torvalds'),
    person(45, 'margaret', 'Margaret Hamilton'),
    // No display name: the handle names the row and gives the initial.
    person(46, 'dennis'),
    person(47, 'barbara', 'Barbara Liskov'),
  ];

  late _MockGetProfilesUseCase useCase;

  setUp(() {
    useCase = _MockGetProfilesUseCase();
    when(
      () => useCase.execute(
        q: any(named: 'q'),
        username: any(named: 'username'),
        displayName: any(named: 'displayName'),
        skills: any(named: 'skills'),
        page: any(named: 'page'),
        pageSize: any(named: 'pageSize'),
        sort: any(named: 'sort'),
        cancellation: any(named: 'cancellation'),
      ),
    ).thenAnswer(
      (_) async => Right(
        PageResult<ProfileEntity>(
          items: people,
          total: people.length,
          page: 1,
          pageSize: 20,
        ),
      ),
    );
  });

  Future<void> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        overrides: [getProfilesUseCaseProvider.overrideWithValue(useCase)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(window: window, child: const ProfilesListScreen()),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpAndSettle();
  }

  testWidgets('every row has a round 40 px face', (tester) async {
    await pump(tester);

    final faces = find.descendant(
      of: find.byType(ChatAvatar),
      matching: find.byType(ClipPath),
    );
    expect(faces, findsNWidgets(people.length));
    for (final face in faces.evaluate()) {
      expect(
        tester.getSize(find.byWidget(face.widget)),
        Size.square(ChatAvatarSize.md.diameter),
      );
    }
  });

  testWidgets('coloured by the user id, as in a chat', (tester) async {
    await pump(tester);

    final theme = ChatixTheme.of(tester.element(find.byType(ListView)));
    for (final profile in people) {
      final avatar = find.byWidgetPredicate(
        (widget) => widget is ChatAvatar && widget.userId == profile.id,
      );
      final fill = tester
          .widgetList<Container>(
            find.descendant(of: avatar, matching: find.byType(Container)),
          )
          .map((container) => container.color)
          .whereType<Color>()
          .first;

      expect(fill, theme.authorColor(profile.id), reason: profile.username);
    }
  });

  testWidgets('a person with no display name is initialled by handle', (
    tester,
  ) async {
    await pump(tester);

    final dennis = find.byWidgetPredicate(
      (widget) => widget is ChatAvatar && widget.userId == 46,
    );
    expect(
      find.descendant(of: dennis, matching: find.text('D')),
      findsOneWidget,
    );
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('contacts, ${window.name}, ${theme.key}', (tester) async {
          await pump(tester, window: window, dark: theme.value);

          await screenMatchesGolden(
            tester,
            'contacts_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}
