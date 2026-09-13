import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/chat_composer.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_context_banner.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_send_button.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../../helpers/chat_golden.dart';

/// The four shapes the composer wears, and the one rule it enforces on its
/// own: nothing goes out past 4096 characters (api-docs §5.4).
void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
  });

  MessageEntity message({String? content = 'the original', int author = 9}) =>
      MessageEntity(
        id: 'm1',
        chatId: 'c1',
        seq: 4,
        authorId: author,
        type: MessageType.text,
        content: content,
        replyToId: null,
        forwardedFromChatId: null,
        forwardedFromMessageId: null,
        forwardedFromAuthorId: null,
        isEdited: false,
        createdAt: DateTime.utc(2026, 1, 1),
        attachments: const [],
      );

  Future<void> pump(
    WidgetTester tester, {
    int? length,
    bool hasAttachments = false,
    bool isRecording = false,
    bool isSending = false,
    SlowMode slowMode = SlowMode.off,
    MessageEntity? replyTo,
    MessageEntity? editing,
    VoidCallback? onSend,
    VoidCallback? onAttach = _noop,
    VoidCallback? onCancelContext,
    void Function(VoiceRecording)? onVoiceRecorded = _ignore,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatComposer(
                controller: controller,
                focusNode: focusNode,
                length: length ?? controller.text.length,
                hasAttachments: hasAttachments,
                isRecording: isRecording,
                isSending: isSending,
                slowMode: slowMode,
                replyTo: replyTo,
                editing: editing,
                onCancelContext: onCancelContext,
                onAttach: onAttach,
                onSend: onSend,
                onVoiceRecorded: onVoiceRecorded,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ComposerSendButton buttonOf(WidgetTester tester) =>
      tester.widget<ComposerSendButton>(find.byType(ComposerSendButton));

  group('what the button is for', () {
    testWidgets('an empty box offers the microphone', (tester) async {
      await pump(tester);

      expect(buttonOf(tester).action, ComposerAction.record);
      expect(buttonOf(tester).enabled, isFalse);
    });

    testWidgets('typing turns it into the plane', (tester) async {
      await pump(tester, length: 4);

      expect(buttonOf(tester).action, ComposerAction.send);
      expect(buttonOf(tester).enabled, isTrue);
    });

    testWidgets('a staged attachment makes an empty box sendable', (
      tester,
    ) async {
      await pump(tester, hasAttachments: true);

      expect(buttonOf(tester).action, ComposerAction.send);
      expect(buttonOf(tester).enabled, isTrue);
    });

    testWidgets('editing turns it into the tick', (tester) async {
      await pump(tester, editing: message(), length: 12);

      expect(buttonOf(tester).action, ComposerAction.save);
    });

    testWidgets('where voice is not on offer, the plane stays put', (
      tester,
    ) async {
      await pump(tester, onVoiceRecorded: null);

      expect(buttonOf(tester).action, ComposerAction.send);
      expect(buttonOf(tester).enabled, isFalse);
    });
  });

  group('the character cap is enforced here, not by the server', () {
    testWidgets('a message at the cap can still go', (tester) async {
      await pump(tester, length: MessageLimits.maxContentLength);

      expect(buttonOf(tester).enabled, isTrue);
    });

    testWidgets('one past it cannot', (tester) async {
      await pump(tester, length: MessageLimits.maxContentLength + 1);

      expect(buttonOf(tester).enabled, isFalse);
    });

    testWidgets('nor can an over-long edit', (tester) async {
      await pump(
        tester,
        editing: message(),
        length: MessageLimits.maxContentLength + 1,
      );

      expect(buttonOf(tester).enabled, isFalse);
    });
  });

  group('which of the four shapes it is in', () {
    ComposerMode modeOf(WidgetTester tester) =>
        tester.widget<ChatComposer>(find.byType(ChatComposer)).mode;

    testWidgets('nothing attached to it: idle', (tester) async {
      await pump(tester);

      expect(modeOf(tester), ComposerMode.idle);
    });

    testWidgets('staged uploads: attaching', (tester) async {
      await pump(tester, hasAttachments: true);

      expect(modeOf(tester), ComposerMode.attaching);
    });

    testWidgets('a reply outranks staged uploads', (tester) async {
      await pump(tester, hasAttachments: true, replyTo: message());

      expect(modeOf(tester), ComposerMode.replying);
    });

    testWidgets('an edit outranks everything', (tester) async {
      await pump(
        tester,
        hasAttachments: true,
        replyTo: message(),
        editing: message(),
        length: 12,
      );

      expect(modeOf(tester), ComposerMode.editing);
    });
  });

  group('the context banner', () {
    testWidgets('is absent in the ordinary case', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.reply_rounded), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });

    testWidgets('a reply names who is being answered', (tester) async {
      await pump(tester, replyTo: message(content: 'ship it'));

      expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
      expect(find.text('ship it'), findsOneWidget);
    });

    testWidgets('an edit says so, and outranks a reply', (tester) async {
      await pump(
        tester,
        replyTo: message(content: 'ship it'),
        editing: message(content: 'the original'),
        length: 12,
      );

      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
      expect(find.byIcon(Icons.reply_rounded), findsNothing);
      expect(find.text('the original'), findsOneWidget);
    });

    testWidgets('a reply to an attachment still has something to show', (
      tester,
    ) async {
      await pump(tester, replyTo: message(content: null));

      expect(find.text('Attachment'), findsOneWidget);
    });

    testWidgets('the cross drops it', (tester) async {
      var cancelled = 0;
      await pump(
        tester,
        replyTo: message(),
        onCancelContext: () => cancelled++,
      );

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();

      expect(cancelled, 1);
    });

    testWidgets('it animates in rather than appearing', (tester) async {
      await pump(tester);
      final without = tester.getSize(find.byType(ComposerContextBanner)).height;

      await pump(tester, replyTo: message());
      final with_ = tester.getSize(find.byType(ComposerContextBanner)).height;

      expect(without, 0);
      expect(with_, greaterThan(0));
    });
  });

  group('attaching', () {
    testWidgets('the paperclip is there for a plain message', (tester) async {
      await pump(tester);

      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    });

    testWidgets('but not while an edit is in the box', (tester) async {
      // `PATCH .../messages/{id}/` carries only `content` (api-docs §5.4).
      await pump(tester, editing: message(), length: 12, onAttach: null);

      expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
    });

    testWidgets('nor while a voice message is being recorded', (tester) async {
      await pump(tester, isRecording: true);

      expect(find.byIcon(Icons.attach_file_rounded), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  testWidgets('a send already in flight cannot be sent again', (tester) async {
    await pump(tester, length: 5, isSending: true);

    expect(buttonOf(tester).enabled, isFalse);
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('the composer on the ${entry.key} theme', (tester) async {
        controller.text = 'Shipping it after lunch then';

        await tester.pumpWidgetBuilder(
          ProviderScope(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChatComposer(
                  controller: controller,
                  focusNode: focusNode,
                  length: controller.text.length,
                  hasAttachments: false,
                  isRecording: false,
                  slowMode: SlowMode.off,
                  replyTo: message(content: 'when does this go out?'),
                  onCancelContext: () {},
                  onAttach: () {},
                  onSend: () {},
                  onVoiceRecorded: _ignore,
                ),
              ],
            ),
          ),
          wrapper: materialAppWrapper(
            theme: chatGoldenTheme(dark: entry.value),
            localizations: AppLocalizations.localizationsDelegates,
          ),
          surfaceSize: const Size(380, 190),
        );

        await screenMatchesGolden(tester, 'composer_reply_${entry.key}');
      });

      testGoldens('the composer near the cap on the ${entry.key} theme', (
        tester,
      ) async {
        controller.text = 'x' * 40;

        await tester.pumpWidgetBuilder(
          ProviderScope(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ChatComposer(
                  controller: controller,
                  focusNode: focusNode,
                  length: MessageLimits.maxContentLength - 12,
                  hasAttachments: false,
                  isRecording: false,
                  slowMode: SlowMode(
                    interval: const Duration(seconds: 30),
                    sendAllowedAt: DateTime.now().add(
                      const Duration(seconds: 18),
                    ),
                  ),
                  onAttach: () {},
                  onSend: () {},
                  onVoiceRecorded: _ignore,
                ),
              ],
            ),
          ),
          wrapper: materialAppWrapper(
            theme: chatGoldenTheme(dark: entry.value),
            localizations: AppLocalizations.localizationsDelegates,
          ),
          surfaceSize: const Size(380, 140),
        );

        await screenMatchesGolden(tester, 'composer_limits_${entry.key}');
      });
    }
  });
}

void _ignore(VoiceRecording _) {}

void _noop() {}
