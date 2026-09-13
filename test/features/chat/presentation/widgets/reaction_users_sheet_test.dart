import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/domain/usecases/get_reactions_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/reaction_users_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

class MockGetReactionsUseCase extends Mock implements GetReactionsUseCase {}

/// Who reacted, per emoji. The list comes from `GET .../reactions/?emoji=…`,
/// which is the only paged view of it (api-docs §5.7.3) — the message itself
/// carries at most three ids.
void main() {
  const chatId = 'c1';
  const messageId = 'm1';

  late MockGetReactionsUseCase useCase;

  setUp(() => useCase = MockGetReactionsUseCase());

  ChatMemberEntity member(int id, String name) => ChatMemberEntity(
    userId: id,
    roleId: 5,
    isMuted: false,
    isBanned: false,
    permissionsOverrides: const {},
    profile: ChatProfileEntity(
      userId: id,
      username: null,
      displayName: name,
      avatarUrl: null,
      avatarS3Key: null,
    ),
  );

  MessageReactionsEntity page(
    List<int> users, {
    bool hasNext = false,
    int? nextUserId,
  }) => MessageReactionsEntity(
    messageId: messageId,
    users: users,
    hasNext: hasNext,
    nextUserId: nextUserId,
  );

  void answer(
    String emoji,
    MessageReactionsEntity result, {
    int? cursorUserId,
  }) {
    when(
      () => useCase.executeUsers(
        chatId,
        messageId,
        emoji: emoji,
        cursorUserId: cursorUserId,
      ),
    ).thenAnswer((_) async => Right(result));
  }

  Future<void> pump(
    WidgetTester tester, {
    required List<ReactionGroupEntity> groups,
    required String emoji,
    List<ChatMemberEntity> members = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [getReactionsUseCaseProvider.overrideWithValue(useCase)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReactionUsersSheet(
              chatId: chatId,
              messageId: messageId,
              emoji: emoji,
              groups: groups,
              members: members,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names and faces the people the roster knows', (tester) async {
    answer('👍', page([7, 9]));

    await pump(
      tester,
      groups: const [ReactionGroupEntity(emoji: '👍', count: 2)],
      emoji: '👍',
      members: [member(7, 'Ada'), member(9, 'Grace')],
    );

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
    expect(find.byType(ChatAvatar), findsNWidgets(2));
  });

  testWidgets('someone off the roster is still shown, by id', (tester) async {
    // The endpoint answers with user ids only; a member loaded after the
    // roster page we have is not a reason to drop a row.
    answer('👍', page([404]));

    await pump(
      tester,
      groups: const [ReactionGroupEntity(emoji: '👍', count: 1)],
      emoji: '👍',
    );

    expect(find.text('User 404'), findsOneWidget);
  });

  testWidgets('one tab per emoji on the message, opening on the pressed one', (
    tester,
  ) async {
    answer('👍', page([7]));
    answer('🔥', page([9]));

    await pump(
      tester,
      groups: const [
        ReactionGroupEntity(emoji: '👍', count: 4),
        ReactionGroupEntity(emoji: '🔥', count: 1),
      ],
      emoji: '🔥',
      members: [member(7, 'Ada'), member(9, 'Grace')],
    );

    expect(find.byType(Tab), findsNWidgets(2));

    // Opened on the tab that was long-pressed, not the first one.
    expect(find.text('Grace'), findsOneWidget);
    expect(find.text('Ada'), findsNothing);
  });

  testWidgets('the other tabs load their own page when reached', (
    tester,
  ) async {
    answer('👍', page([7]));
    answer('🔥', page([9]));

    await pump(
      tester,
      groups: const [
        ReactionGroupEntity(emoji: '👍', count: 4),
        ReactionGroupEntity(emoji: '🔥', count: 1),
      ],
      emoji: '👍',
      members: [member(7, 'Ada'), member(9, 'Grace')],
    );

    expect(find.text('Ada'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(TabBar), matching: find.text('🔥')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Grace'), findsOneWidget);
    verify(
      () => useCase.executeUsers(
        chatId,
        messageId,
        emoji: '🔥',
        cursorUserId: null,
      ),
    ).called(1);
  });

  testWidgets('a single emoji needs no tab bar', (tester) async {
    answer('👍', page([7]));

    await pump(
      tester,
      groups: const [ReactionGroupEntity(emoji: '👍', count: 1)],
      emoji: '👍',
      members: [member(7, 'Ada')],
    );

    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('the next page is fetched from next_user_id', (tester) async {
    answer('👍', page([7], hasNext: true, nextUserId: 9));
    answer('👍', page([9]), cursorUserId: 9);

    await pump(
      tester,
      groups: const [ReactionGroupEntity(emoji: '👍', count: 2)],
      emoji: '👍',
      members: [member(7, 'Ada'), member(9, 'Grace')],
    );

    expect(find.text('Grace'), findsNothing);

    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();

    expect(find.text('Ada'), findsOneWidget);
    expect(find.text('Grace'), findsOneWidget);
  });

  testWidgets('a failed page offers a retry rather than an empty list', (
    tester,
  ) async {
    when(
      () => useCase.executeUsers(
        chatId,
        messageId,
        emoji: '👍',
        cursorUserId: null,
      ),
    ).thenAnswer((_) async => const Left(NetworkFailure()));

    await pump(
      tester,
      groups: const [ReactionGroupEntity(emoji: '👍', count: 1)],
      emoji: '👍',
    );

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
