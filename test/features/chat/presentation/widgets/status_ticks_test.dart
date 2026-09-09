import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';

void main() {
  group('resolveDeliveryStatus', () {
    MessageDeliveryStatus? resolve({
      bool isMine = true,
      bool isDirect = true,
      bool isPending = false,
      int seq = 10,
      int? peerReadSeq,
    }) => resolveDeliveryStatus(
      isMine: isMine,
      isDirect: isDirect,
      isPending: isPending,
      seq: seq,
      peerReadSeq: peerReadSeq,
    );

    test('someone else\'s message never carries ticks', () {
      expect(resolve(isMine: false, peerReadSeq: 99), isNull);
      expect(resolve(isMine: false, isPending: true), isNull);
    });

    test('a queued message shows the clock', () {
      expect(resolve(isPending: true), MessageDeliveryStatus.sending);
    });

    test('the clock wins over everything, including a group', () {
      expect(
        resolve(isPending: true, isDirect: false),
        MessageDeliveryStatus.sending,
      );
    });

    test('a group message stops at "no ticks" once it is sent', () {
      // `messages_read` reports one reader_id and a seq (api-docs §6.4);
      // nothing in it says the other 29 members have read anything.
      expect(resolve(isDirect: false, peerReadSeq: 99), isNull);
    });

    test('an unknown read position is "sent", not "unread"', () {
      expect(resolve(peerReadSeq: null), MessageDeliveryStatus.sent);
    });

    test('the peer reading past this message makes it read', () {
      expect(resolve(seq: 10, peerReadSeq: 10), MessageDeliveryStatus.read);
      expect(resolve(seq: 10, peerReadSeq: 11), MessageDeliveryStatus.read);
    });

    test('a read cursor behind this message leaves it sent', () {
      expect(resolve(seq: 10, peerReadSeq: 9), MessageDeliveryStatus.sent);
    });
  });

  group('StatusTicks', () {
    Future<void> pumpTicks(
      WidgetTester tester,
      MessageDeliveryStatus status,
    ) => tester.pumpWidgetBuilder(
      StatusTicks(status: status),
      wrapper: materialAppWrapper(
        theme: chatGoldenTheme(dark: false),
        localizations: AppLocalizations.localizationsDelegates,
      ),
    );

    testWidgets('each state draws its own glyph', (tester) async {
      await pumpTicks(tester, MessageDeliveryStatus.sending);
      expect(find.byIcon(Icons.access_time), findsOneWidget);

      await pumpTicks(tester, MessageDeliveryStatus.sent);
      expect(find.byIcon(Icons.done), findsOneWidget);

      await pumpTicks(tester, MessageDeliveryStatus.read);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
    });

    testWidgets('every state is announced to screen readers', (tester) async {
      for (final status in MessageDeliveryStatus.values) {
        await pumpTicks(tester, status);
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.semanticLabel, isNotNull, reason: status.name);
        expect(icon.semanticLabel, isNotEmpty, reason: status.name);
      }
    });
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('delivery states on the ${entry.key} theme', (tester) async {
        await pumpChatGolden(
          tester,
          name: 'status_ticks_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(280, 90),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final status in MessageDeliveryStatus.values)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusTicks(status: status, size: 20),
                    const SizedBox(height: 6),
                    Text(status.name),
                  ],
                ),
            ],
          ),
        );
      });
    }
  });
}
