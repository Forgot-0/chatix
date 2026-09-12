import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_search.dart';
import 'package:chatix/features/chat/presentation/providers/in_chat_search_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/in_chat_search_bar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

/// Stands in for a search that has already run, so the bar can be looked at
/// on its own.
class _StubSearchController extends InChatSearchController {
  _StubSearchController(super.chatId, this._state);

  final InChatSearchState _state;

  @override
  InChatSearchState build() => _state;
}

void main() {
  final l10n = AppLocalizationsEn();

  const chatId = 'a';

  MessageSearchHit hit(int seq) => MessageSearchHit(
    message: MessageEntity(
      id: 'm-$seq',
      chatId: chatId,
      seq: seq,
      authorId: 9,
      type: MessageType.text,
      content: 'ship it',
      replyToId: null,
      forwardedFromChatId: null,
      forwardedFromMessageId: null,
      forwardedFromAuthorId: null,
      isEdited: false,
      createdAt: DateTime.utc(2026, 3, 10, seq),
    ),
    snippet: 'ship it',
    matchStart: 0,
    matchLength: 4,
  );

  Future<void> pumpBar(
    WidgetTester tester,
    InChatSearchState state, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inChatSearchProvider(chatId).overrideWith(
            () => _StubSearchController(chatId, state),
          ),
        ],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(InChatSearchBar.height),
              child: InChatSearchBar(chatId: chatId),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('before anything is typed it says what it can see', (
    tester,
  ) async {
    await pumpBar(tester, const InChatSearchState());

    expect(find.text(l10n.searchLoadedHistoryOnly), findsOneWidget);
  });

  testWidgets('it counts the matches and which one you are on', (
    tester,
  ) async {
    await pumpBar(
      tester,
      InChatSearchState(query: 'ship', hits: [hit(9), hit(4)], index: 1),
    );

    expect(find.text(l10n.searchMatchPosition(2, 2)), findsOneWidget);
  });

  testWidgets('the arrows stop at the ends of the list', (tester) async {
    await pumpBar(
      tester,
      InChatSearchState(query: 'ship', hits: [hit(9), hit(4)]),
    );

    final newer = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.keyboard_arrow_down),
    );
    final older = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.keyboard_arrow_up),
    );

    // Parked on the newest match: there is nothing newer to go to.
    expect(newer.onPressed, isNull);
    expect(older.onPressed, isNotNull);
  });

  testWidgets('a query with nothing behind it says so', (tester) async {
    await pumpBar(tester, const InChatSearchState(query: 'ship'));

    expect(find.text(l10n.searchNoMatches), findsOneWidget);
  });

  testWidgets('a search in flight shows progress, not a count', (
    tester,
  ) async {
    await pumpBar(
      tester,
      const InChatSearchState(query: 'ship', isSearching: true),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(l10n.searchNoMatches), findsNothing);
  });

  testWidgets('the bar is drawn on both grounds', (tester) async {
    await pumpBar(
      tester,
      InChatSearchState(query: 'ship', hits: [hit(9)]),
      dark: true,
    );

    expect(tester.takeException(), isNull);
  });
}
