import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/ui/feedback/connection_strip.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_banners.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Three states and only three: connecting, waiting for a network, and
/// nothing at all — and nothing at all is the one that matters most, since a
/// reconnect that succeeds in a second should leave no mark on the screen.
/// What the strip is told the connection is doing, and a way to change it
/// mid-test — which is the only interesting thing about a status indicator.
class _Status extends Notifier<ChatSocketStatus> {
  static ChatSocketStatus initial = ChatSocketStatus.ready;

  @override
  ChatSocketStatus build() => initial;

  void report(ChatSocketStatus next) => state = next;
}

final _statusProvider = NotifierProvider<_Status, ChatSocketStatus>(
  _Status.new,
);

void main() {
  Future<void> show(
    WidgetTester tester, {
    required ChatSocketStatus initial,
    bool hasLink = true,
  }) async {
    _Status.initial = initial;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatSocketStateProvider.overrideWith(
            (ref) => ref.watch(_statusProvider),
          ),
          hasNetworkLinkProvider.overrideWithValue(hasLink),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Column(children: [ChatConnectionStrip()])),
        ),
      ),
    );
  }

  /// Long enough for the strip to decide the outage is worth mentioning.
  Future<void> settle(WidgetTester tester) => tester.pump(
    ChatConnectionStrip.settleDelay + const Duration(milliseconds: 50),
  );

  /// Drains the strip's own countdown so nothing outlives the tree.
  Future<void> finish(WidgetTester tester) async =>
      tester.pump(ChatConnectionStrip.settleDelay);

  testWidgets('says nothing while the connection is fine', (tester) async {
    await show(tester, initial: ChatSocketStatus.ready);
    await settle(tester);

    expect(tester.getSize(find.byType(ConnectionStrip)).height, 0);
    expect(find.text('Connecting…'), findsNothing);
  });

  testWidgets('a blink of a reconnect leaves no mark', (tester) async {
    // The first backoff step is a second, so most reconnects are over before
    // anybody could read a word about them.
    await show(tester, initial: ChatSocketStatus.reconnecting);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Connecting…'), findsNothing);
    expect(find.text('Waiting for network'), findsNothing);

    await settle(tester);
  });

  testWidgets('an outage that lasts says it is connecting', (tester) async {
    await show(tester, initial: ChatSocketStatus.reconnecting);
    await settle(tester);

    expect(find.text('Connecting…'), findsOneWidget);
    expect(find.text('Waiting for network'), findsNothing);
  });

  testWidgets('a first connection is the same kind of news', (tester) async {
    await show(tester, initial: ChatSocketStatus.connecting);
    await settle(tester);

    expect(find.text('Connecting…'), findsOneWidget);
  });

  testWidgets('with no network at all it says so instead', (tester) async {
    // Not the app's problem to solve, and not something it can hurry.
    await show(
      tester,
      initial: ChatSocketStatus.reconnecting,
      hasLink: false,
    );
    await settle(tester);

    expect(find.text('Waiting for network'), findsOneWidget);
    expect(find.text('Connecting…'), findsNothing);
  });

  testWidgets('a socket that stopped trying is waiting, not working', (
    tester,
  ) async {
    await show(tester, initial: ChatSocketStatus.disconnected);
    await settle(tester);

    expect(find.text('Waiting for network'), findsOneWidget);
  });

  testWidgets('it goes away again when the connection comes back', (
    tester,
  ) async {
    await show(tester, initial: ChatSocketStatus.reconnecting);
    await settle(tester);
    expect(find.text('Connecting…'), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatConnectionStrip)),
    );
    container.read(_statusProvider.notifier).report(ChatSocketStatus.ready);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.getSize(find.byType(ConnectionStrip)).height, 0);
    await finish(tester);
  });
}
