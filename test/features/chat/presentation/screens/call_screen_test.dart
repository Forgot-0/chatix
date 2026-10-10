import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/storage_providers.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/active_call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/screens/call_screen.dart';
import 'package:chatix/features/chat/presentation/widgets/call_mini_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

const String _chatId = 'c0ffee00-1d2a-4c5b-8e7f-6a5b4c3d2e1f';

/// A call that is already up, without LiveKit behind it.
class _LiveCall extends CallController {
  @override
  CallState build() => CallState(
    stage: CallStage.connected,
    chatId: _chatId,
    chatName: 'Release crew',
    connectedAt: DateTime(2026, 10, 10, 12),
  );
}

/// The chat behind the call, never arriving: the screen names the call
/// generically meanwhile, which is all this test needs of it.
class _PendingDetail extends ChatDetailController {
  _PendingDetail() : super(_chatId);

  @override
  Future<ChatDetailState> build() => Completer<ChatDetailState>().future;
}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

/// The call screen hands the call back to the mini player when it goes.
///
/// It used to say so with `ref` in dispose(), which Riverpod 3 refuses with
/// a StateError — so the "call screen is up" flag stayed set, and the mini
/// player never came back for a call that was still running.
void main() {
  Future<NavigatorState> pumpApp(
    WidgetTester tester, {
    Widget home = const Scaffold(body: SizedBox.expand()),
  }) async {
    final navigator = GlobalKey<NavigatorState>();

    // The call screen draws itself in the app's dark theme, which is built
    // from the appearance settings kept in preferences.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          callProvider.overrideWith(_LiveCall.new),
          chatDetailProvider(_chatId).overrideWith(_PendingDetail.new),
          authProvider.overrideWith(_FakeAuthController.new),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Where MyApp puts it: over the router, under nothing.
          builder: (context, child) => CallOverlay(child: child!),
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return navigator.currentState!;
  }

  testWidgets('leaving the call screen brings the mini player back', (
    tester,
  ) async {
    final navigator = await pumpApp(tester);
    expect(find.byType(CallMiniPlayer), findsOneWidget);

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const CallScreen(chatId: _chatId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CallMiniPlayer), findsNothing);

    navigator.pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(CallMiniPlayer), findsOneWidget);
  });

  testWidgets('a second visit hides it again and gives it back again', (
    tester,
  ) async {
    final navigator = await pumpApp(tester);

    for (var visit = 0; visit < 2; visit++) {
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => const CallScreen(chatId: _chatId),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CallMiniPlayer), findsNothing);

      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(CallMiniPlayer), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the pill can show its tooltips and lets other taps through', (
    tester,
  ) async {
    // The overlay sits above the navigator, so the navigator's own Overlay
    // is not an ancestor of the pill: its tooltips need one of their own.
    var taps = 0;
    await pumpApp(
      tester,
      home: Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => taps++,
            child: const Text('Under'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.longPress(find.byIcon(Icons.mic_off));
    await tester.pumpAndSettle();
    expect(find.text('Unmute'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Under'));
    expect(taps, 1);
  });

  testWidgets('the flag is the screen\'s own, not left behind', (tester) async {
    final navigator = await pumpApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CallOverlay)),
    );

    unawaited(
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const CallScreen(chatId: _chatId),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(callScreenVisibleProvider), isTrue);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(container.read(callScreenVisibleProvider), isFalse);
  });
}
