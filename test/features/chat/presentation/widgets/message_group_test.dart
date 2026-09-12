import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';

/// A run of messages by one author reads as one block: the clock appears once,
/// at the bottom of the run, and the gaps inside it are tighter than the gap
/// between runs.
void main() {
  MessageEntity message({
    required int seq,
    String? content,
    bool isEdited = false,
    int? authorId = 42,
  }) => MessageEntity(
    id: 'm$seq',
    chatId: 'c',
    seq: seq,
    authorId: authorId,
    type: MessageType.text,
    content: content ?? 'message $seq',
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: isEdited,
    createdAt: DateTime(2026, 1, 1, 14, 30),
    attachments: const [],
  );

  Widget bubble({
    required MessageEntity message,
    required bool isFirst,
    required bool isLast,
    bool isMine = false,
  }) => MessageBubble(
    message: message,
    isMine: isMine,
    isFirstInGroup: isFirst,
    isLastInGroup: isLast,
    showAuthor: isFirst && !isMine,
    showMeta: isLast,
    deliveryStatus: isMine && isLast ? MessageDeliveryStatus.read : null,
  );

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidgetBuilder(
        Column(mainAxisSize: MainAxisSize.min, children: [child]),
        wrapper: materialAppWrapper(
          theme: chatGoldenTheme(dark: false),
          localizations: AppLocalizations.localizationsDelegates,
        ),
        surfaceSize: const Size(360, 400),
      );

  testWidgets('only the last message of a run shows the time', (tester) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble(message: message(seq: 1), isFirst: true, isLast: false),
          bubble(message: message(seq: 2), isFirst: false, isLast: false),
          bubble(message: message(seq: 3), isFirst: false, isLast: true),
        ],
      ),
    );

    expect(find.text('14:30'), findsOneWidget);
  });

  testWidgets('only the first message of a run names its author', (
    tester,
  ) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble(message: message(seq: 1), isFirst: true, isLast: false),
          bubble(message: message(seq: 2), isFirst: false, isLast: true),
        ],
      ),
    );

    expect(find.text('User #42'), findsOneWidget);
  });

  testWidgets('an edited message keeps its clock wherever it sits', (
    tester,
  ) async {
    // The "edited" mark lives on the timestamp row. Hiding that row mid-run
    // would drop the only sign the text ever changed.
    await pump(
      tester,
      bubble(
        message: message(seq: 2, isEdited: true),
        isFirst: false,
        isLast: false,
      ),
    );

    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('edited'), findsOneWidget);
  });

  testWidgets('ticks ride the last message of my own run', (tester) async {
    await pump(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble(
            message: message(seq: 1, authorId: 7),
            isFirst: true,
            isLast: false,
            isMine: true,
          ),
          bubble(
            message: message(seq: 2, authorId: 7),
            isFirst: false,
            isLast: true,
            isMine: true,
          ),
        ],
      ),
    );

    expect(find.byType(StatusTicks), findsOneWidget);
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('a run of messages on the ${entry.key} theme', (
        tester,
      ) async {
        await pumpChatGolden(
          tester,
          name: 'message_group_${entry.key}',
          dark: entry.value,
          surfaceSize: const Size(360, 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              bubble(
                message: message(seq: 1, content: 'First of the run'),
                isFirst: true,
                isLast: false,
              ),
              bubble(
                message: message(seq: 2, content: 'Middle, no clock'),
                isFirst: false,
                isLast: false,
              ),
              bubble(
                message: message(seq: 3, content: 'Last, with the time'),
                isFirst: false,
                isLast: true,
              ),
              bubble(
                message: message(seq: 4, content: 'A new run answers'),
                isFirst: true,
                isLast: true,
                isMine: true,
              ),
            ],
          ),
        );
      });
    }
  });
}
