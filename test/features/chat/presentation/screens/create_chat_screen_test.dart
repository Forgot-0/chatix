import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/screens/create_chat_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/pane_frame.dart';

class _MockCreateChatUseCase extends Mock implements CreateChatUseCase {}

/// The new-chat form says everything in the reader's language — its labels,
/// its hints and its refusals — and never names a permission string.
void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
    registerFallbackValue(ChatType.group);
  });

  late _MockCreateChatUseCase createChat;

  setUp(() => createChat = _MockCreateChatUseCase());

  void answerCreate(Either<Failure, ChatEntity> result) {
    when(
      () => createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    ).thenAnswer((_) async => result);
  }

  Future<void> pumpForm(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    String? initialType,
  }) async {
    await tester.pumpWidgetBuilder(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [createChatUseCaseProvider.overrideWithValue(createChat)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PaneFrame(
            window: window,
            child: CreateChatScreen(initialType: initialType),
          ),
        ),
      ),
      wrapper: (child) => child,
      surfaceSize: window.size,
    );
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpAndSettle();
  }

  Future<void> tapCreate(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Создать чат');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets('a direct chat asks for its one person in Russian', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Кому вы хотите написать?'), findsOneWidget);
    expect(
      find.text('Выберите одного человека — в личном чате ровно два участника'),
      findsOneWidget,
    );

    await tapCreate(tester);

    expect(
      find.text(
        'Для личного чата нужен ровно один собеседник — найдите его по '
        'имени или @username',
      ),
      findsOneWidget,
    );
    verifyNever(
      () => createChat.execute(
        name: any(named: 'name'),
        description: any(named: 'description'),
        chatType: any(named: 'chatType'),
        memberIds: any(named: 'memberIds'),
        isPublic: any(named: 'isPublic'),
        adminOnly: any(named: 'adminOnly'),
        slowModeSeconds: any(named: 'slowModeSeconds'),
        permissions: any(named: 'permissions'),
      ),
    );
  });

  testWidgets('a group says who may post, not which right decides it', (
    tester,
  ) async {
    await pumpForm(tester, initialType: 'group');

    expect(find.text('Добавить по имени или @username'), findsOneWidget);
    expect(
      find.text('Сейчас — до 100 человек, остальных можно добавить позже'),
      findsOneWidget,
    );
    expect(find.text('Писать могут только администраторы'), findsOneWidget);
    expect(find.textContaining('send_admin_only'), findsNothing);
    expect(find.text('от 0 до 86400 секунд'), findsOneWidget);
  });

  testWidgets('a group with no name is stopped before the request', (
    tester,
  ) async {
    await pumpForm(tester, initialType: 'group');

    await tapCreate(tester);

    expect(find.text('Укажите название чата'), findsOneWidget);
  });

  testWidgets('slow mode out of range is said before the request', (
    tester,
  ) async {
    await pumpForm(tester, initialType: 'group');
    await tester.enterText(find.byType(TextField).first, 'Релиз');
    final slowMode = find.ancestor(
      of: find.text('Медленный режим (секунды)'),
      matching: find.byType(TextField),
    );
    await tester.enterText(slowMode, '90000');

    await tapCreate(tester);

    expect(find.text('от 0 до 86400 секунд'), findsNWidgets(2));
  });

  testWidgets('a refusal from the server is the reader\'s sentence', (
    tester,
  ) async {
    answerCreate(
      const Left(
        ApiFailure(
          code: 'MEMBER_LIMIT_EXCEEDED',
          message: 'Member limit exceeded',
          detail: {'limit': 500},
          status: 400,
        ),
      ),
    );
    await pumpForm(tester, initialType: 'group');
    await tester.enterText(find.byType(TextField).first, 'Релиз');

    await tapCreate(tester);

    final l10n = AppLocalizationsLookup.ru;
    expect(find.text(l10n.apiErrorLimitExceededGeneric), findsOneWidget);
    expect(find.textContaining('Member limit'), findsNothing);
  });

  group('goldens', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('new group, ${window.name}, ${theme.key}', (tester) async {
          await pumpForm(
            tester,
            window: window,
            dark: theme.value,
            initialType: 'group',
          );
          // The refusal is part of what changed: shown, in Russian.
          await tapCreate(tester);

          await screenMatchesGolden(
            tester,
            'create_chat_group_${window.name}_${theme.key}',
          );
        });
      }
    }
  });
}

/// The Russian catalogue, for a sentence the test should not retype.
abstract final class AppLocalizationsLookup {
  static final AppLocalizations ru = lookupAppLocalizations(const Locale('ru'));
}
