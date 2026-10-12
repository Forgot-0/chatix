import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/settings/send_shortcut.dart';
import 'package:chatix/features/chat/data/datasources/clipboard_attachments.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_detail_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/composer_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/bubble_hover_actions.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_drop_zone.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_field.dart';
import 'package:chatix/features/chat/presentation/widgets/in_chat_search_bar.dart';
import 'package:chatix/features/chat/presentation/widgets/message_bubble.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/chat_golden.dart';
import '../../../../helpers/chat_screen_harness.dart';
import '../../../../helpers/pane_frame.dart';

class _MockSendMessageUseCase extends Mock implements SendMessageUseCase {}

/// The clipboard as the test sets it: whatever [uploads] holds is "on it".
class _FakeClipboardReader implements ClipboardAttachmentReader {
  List<AttachmentUploadRequestEntity> uploads = const [];
  int reads = 0;

  @override
  Future<List<AttachmentUploadRequestEntity>> read() async {
    reads++;
    return uploads;
  }
}

void main() {
  setUpAll(ChatScreenHarness.setUpAll);

  final l10n = AppLocalizationsRu();
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  late ChatScreenHarness harness;
  late _MockSendMessageUseCase send;
  late _FakeClipboardReader clipboard;

  setUp(() {
    harness = ChatScreenHarness()..setUp();
    send = _MockSendMessageUseCase();
    clipboard = _FakeClipboardReader();

    when(
      () => send.execute(
        any(),
        content: any(named: 'content'),
        replyToId: any(named: 'replyToId'),
        messageType: any(named: 'messageType'),
        uploadTokens: any(named: 'uploadTokens'),
        idempotencyKey: any(named: 'idempotencyKey'),
      ),
    ).thenAnswer(
      (invocation) async => Right(
        harness.message(
          4,
          ChatScreenHarness.myself,
          invocation.namedArguments[#content] as String,
        ),
      ),
    );
  });

  tearDown(() async {
    EditableText.debugDeterministicCursor = false;
    await harness.tearDown();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    PaneWindow window = PaneWindow.phone,
    bool dark = false,
    bool routed = false,
    SendShortcut shortcut = SendShortcut.enter,
  }) async {
    // The quick reactions come from this device's history; without one the
    // react button has nothing to offer and stays away.
    await harness.prefs.writeRecentReactions(['👍', '🔥', '🎉', '😂', '❤️']);

    return harness.pump(
      tester,
      window: window,
      dark: dark,
      routed: routed,
      overrides: [
        sendMessageUseCaseProvider.overrideWithValue(send),
        clipboardAttachmentReaderProvider.overrideWithValue(clipboard),
        sendShortcutStoreProvider.overrideWithValue(
          InMemorySendShortcutStore(shortcut),
        ),
      ],
    );
  }

  Finder composerField() => find.descendant(
    of: find.byType(ComposerField),
    matching: find.byType(TextField),
  );

  String composerText(WidgetTester tester) =>
      tester.widget<TextField>(composerField()).controller!.text;

  /// The painted bubble — the row around it spans the whole feed.
  Finder bubble(String text) => find
      .ancestor(
        of: find.descendant(
          of: find.byType(MessageBubble),
          matching: find.text(text),
        ),
        matching: find.byType(KeyedSubtree),
      )
      .first;

  /// Lets the delivery's read report go out: it waits a moment after the
  /// message lands, and a timer left behind fails the test.
  Future<void> settleDelivery(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  void verifySent(String content) => verify(
    () => send.execute(
      ChatScreenHarness.chatId,
      content: content,
      replyToId: any(named: 'replyToId'),
      messageType: any(named: 'messageType'),
      uploadTokens: any(named: 'uploadTokens'),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  ).called(1);

  void verifyNothingSent() => verifyNever(
    () => send.execute(
      any(),
      content: any(named: 'content'),
      replyToId: any(named: 'replyToId'),
      messageType: any(named: 'messageType'),
      uploadTokens: any(named: 'uploadTokens'),
      idempotencyKey: any(named: 'idempotencyKey'),
    ),
  );

  Future<void> withModifier(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
  }

  group('the composer, from the keyboard', () {
    testWidgets('takes the caret as the chat opens', (tester) async {
      await pump(tester);

      final field = tester.widget<TextField>(composerField());
      expect(field.focusNode!.hasFocus, isTrue);
    }, variant: windows);

    testWidgets('Enter sends; Shift+Enter leaves the line to the field', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(composerField(), 'Готово, отправил');
      // A key before the next frame races the field's own echo of the text.
      await tester.pump();

      await withModifier(
        tester,
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.enter,
      );
      await tester.pump();
      verifyNothingSent();
      expect(composerText(tester), 'Готово, отправил');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await settleDelivery(tester);

      verifySent('Готово, отправил');
      expect(composerText(tester), isEmpty);
    }, variant: windows);

    testWidgets('with Ctrl+Enter chosen, Enter is a new line', (tester) async {
      await pump(tester, shortcut: SendShortcut.modifierEnter);
      await tester.enterText(composerField(), 'Длинное сообщение');
      // A key before the next frame races the field's own echo of the text.
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      verifyNothingSent();

      await withModifier(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.enter,
      );
      await settleDelivery(tester);
      verifySent('Длинное сообщение');
    }, variant: windows);

    testWidgets('an empty field sends nothing', (tester) async {
      await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      verifyNothingSent();
    }, variant: windows);

    testWidgets('↑ in an empty field opens my last message for editing', (
      tester,
    ) async {
      final container = await pump(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      final composer = container.read(
        composerProvider(ChatScreenHarness.chatId),
      );
      expect(composer.editing?.id, 'm3');
      expect(composerText(tester), 'Отправлю до обеда');
    }, variant: windows);

    testWidgets('↑ with text in the field is the field\'s', (tester) async {
      final container = await pump(tester);
      await tester.enterText(composerField(), 'черновик');
      // A key before the next frame races the field's own echo of the text.
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      expect(
        container.read(composerProvider(ChatScreenHarness.chatId)).isEditing,
        isFalse,
      );
      expect(composerText(tester), 'черновик');
    }, variant: windows);

    testWidgets(
      'a phone keeps its return key: Enter does not send',
      (tester) async {
        final container = await pump(tester);
        await tester.enterText(composerField(), 'Готово');
        // A key before the next frame races the field's own echo of the text.
        await tester.pump();

        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();

        verifyNothingSent();
        expect(
          container.read(composerProvider(ChatScreenHarness.chatId)).isEditing,
          isFalse,
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('Esc', () {
    testWidgets('drops the reply first, then closes the chat', (tester) async {
      final container = await pump(tester, routed: true);

      await ChatScreenHarness.pickFromMenu(
        tester,
        'Заметки к релизу готовы?',
        l10n.messageReply,
      );
      expect(
        container
            .read(chatDetailProvider(ChatScreenHarness.chatId))
            .value
            ?.replyTo,
        isNotNull,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        container
            .read(chatDetailProvider(ChatScreenHarness.chatId))
            .value
            ?.replyTo,
        isNull,
      );
      expect(find.text(ChatScreenHarness.chatsRootLabel), findsNothing);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text(ChatScreenHarness.chatsRootLabel), findsOneWidget);
    }, variant: windows);

    testWidgets('abandons an edit and puts the draft back', (tester) async {
      final container = await pump(tester, routed: true);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(
        container.read(composerProvider(ChatScreenHarness.chatId)).isEditing,
        isFalse,
      );
      expect(composerText(tester), isEmpty);
      expect(find.text(ChatScreenHarness.chatsRootLabel), findsNothing);
    }, variant: windows);

    testWidgets('closes the search before the chat', (tester) async {
      final container = await pump(tester, routed: true);

      // What Ctrl+F asks for from the shell.
      container
          .read(chatSearchRequestProvider.notifier)
          .open(ChatScreenHarness.chatId);
      await tester.pumpAndSettle();
      expect(find.byType(InChatSearchBar), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(InChatSearchBar), findsNothing);
      expect(find.byType(ComposerField), findsOneWidget);
      expect(find.text(ChatScreenHarness.chatsRootLabel), findsNothing);
    }, variant: windows);

    testWidgets('in two panes, deselects the chat', (tester) async {
      await pump(tester, routed: true, window: PaneWindow.desktop);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text(ChatScreenHarness.chatsRootLabel), findsOneWidget);
    }, variant: windows);
  });

  group('Ctrl+V', () {
    testWidgets('with a picture on the clipboard opens the preview', (
      tester,
    ) async {
      clipboard.uploads = const [
        AttachmentUploadRequestEntity(
          filename: 'image_20261012_140305.png',
          mimeType: 'image/png',
          fileSize: 2048,
          filePath: 'image_20261012_140305.png',
        ),
      ];
      await pump(tester, routed: true);

      await withModifier(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyV,
      );
      await tester.pumpAndSettle();

      expect(clipboard.reads, 1);
      expect(
        find.text(AttachPreviewProbe.labelFor(['image_20261012_140305.png'])),
        findsOneWidget,
      );
    }, variant: windows);

    testWidgets('with only text leaves the paste to the field', (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => switch (call.method) {
          'Clipboard.getData' => {'text': 'из буфера'},
          'Clipboard.hasStrings' => {'value': true},
          _ => null,
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester, routed: true);

      await withModifier(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.keyV,
      );
      await tester.pumpAndSettle();

      expect(clipboard.reads, 1);
      expect(composerText(tester), 'из буфера');
      expect(find.byType(AttachPreviewProbe), findsNothing);
    }, variant: windows);
  });

  group('dragging files in', () {
    Future<void> dropEvent(String method, Object arguments) async {
      final binding = TestDefaultBinaryMessengerBinding.instance;
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        'desktop_drop',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall(method, arguments),
        ),
        (_) {},
      );
    }

    double plateOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(
          find.ancestor(
            of: find.byType(ChatDropPlate),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .opacity;

    testWidgets('lights the zone, and the drop opens the preview', (
      tester,
    ) async {
      await pump(tester, routed: true);
      expect(plateOpacity(tester), 0);

      await dropEvent('entered', <double>[200, 400]);
      await tester.pumpAndSettle();
      expect(plateOpacity(tester), 1);
      expect(find.text(l10n.chatDropTitle), findsOneWidget);

      final dir = Directory.systemTemp.createTempSync('chatix_drop');
      addTearDown(() {
        try {
          dir.deleteSync(recursive: true);
        } on FileSystemException {
          // Windows may still hold the file for a moment.
        }
      });
      final photo = File('${dir.path}${Platform.pathSeparator}sunset.png')
        ..writeAsBytesSync(img.encodePng(img.Image(width: 2, height: 2)));

      await tester.runAsync(() async {
        await dropEvent('performOperation', <String>[photo.path]);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();

      expect(
        find.text(AttachPreviewProbe.labelFor(['sunset.png'])),
        findsOneWidget,
      );
    }, variant: windows);

    testWidgets('goes dark again when the drag leaves', (tester) async {
      await pump(tester, routed: true);

      await dropEvent('entered', <double>[200, 400]);
      await tester.pumpAndSettle();
      await dropEvent('exited', <double>[0, 0]);
      await tester.pumpAndSettle();

      expect(plateOpacity(tester), 0);
    }, variant: windows);

    testWidgets(
      'a phone has no zone at all',
      (tester) async {
        await pump(tester);

        expect(find.byType(ChatDropPlate), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );
  });

  group('the mouse', () {
    testWidgets('a right click opens the menu at the pointer', (tester) async {
      final container = await pump(tester, window: PaneWindow.desktop);
      final at = tester.getCenter(find.text('Заметки к релизу готовы?'));
      final blursBefore = find.byType(BackdropFilter).evaluate().length;

      await tester.tapAt(
        at,
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      // The same items the long press offers…
      final reply = find.text(l10n.messageReply);
      expect(reply, findsOneWidget);
      expect(find.text(l10n.messageCopy), findsOneWidget);
      // …but no blur over the conversation: it stays as it is.
      expect(find.byType(BackdropFilter), findsNWidgets(blursBefore));

      // Opened from the click: one of the menu's corners is where the
      // pointer was — which one depends on where the window has room.
      Rect panel(Finder inside) => tester.getRect(
        find.ancestor(of: inside, matching: find.byType(Material)).first,
      );
      final menu = panel(
        reply,
      ).expandToInclude(panel(find.byTooltip(l10n.moreReactions)));
      final corners = [
        menu.topLeft,
        menu.topRight,
        menu.bottomLeft,
        menu.bottomRight,
      ];
      expect(
        corners.map((corner) => (corner - at).distance).reduce(math.min),
        lessThan(1),
      );

      await tester.tap(reply);
      await tester.pumpAndSettle();
      expect(
        container
            .read(chatDetailProvider(ChatScreenHarness.chatId))
            .value
            ?.replyTo
            ?.id,
        'm1',
      );
    }, variant: windows);

    testWidgets('a click outside the menu closes it', (tester) async {
      await pump(tester, window: PaneWindow.desktop);

      await tester.tapAt(
        tester.getCenter(find.text('Отправлю до обеда')),
        buttons: kSecondaryMouseButton,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();
      expect(find.text(l10n.messageReply), findsOneWidget);

      await tester.tapAt(const Offset(700, 120));
      await tester.pumpAndSettle();
      expect(find.text(l10n.messageReply), findsNothing);
    }, variant: windows);

    testWidgets('hovering a bubble brings up reply and react beside it', (
      tester,
    ) async {
      final container = await pump(tester, window: PaneWindow.desktop);
      final target = bubble('Заметки к релизу готовы?');
      final bubbleRect = tester.getRect(target);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      expect(find.byType(BubbleHoverActions), findsNothing);

      await mouse.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();

      final actions = find.byType(BubbleHoverActions);
      expect(actions, findsOneWidget);
      // Beside the bubble, not over it, and the bubble has not moved.
      final pill = tester.getRect(actions);
      expect(pill.left, greaterThan(bubbleRect.right));
      expect(tester.getRect(target), bubbleRect);

      // Reaching for the buttons keeps them up.
      await mouse.moveTo(pill.center);
      await tester.pumpAndSettle();
      expect(actions, findsOneWidget);

      await tester.tap(find.byTooltip(l10n.messageReply));
      await tester.pumpAndSettle();
      expect(
        container
            .read(chatDetailProvider(ChatScreenHarness.chatId))
            .value
            ?.replyTo
            ?.id,
        'm1',
      );

      await mouse.moveTo(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(BubbleHoverActions), findsNothing);
    }, variant: windows);

    testWidgets('react on hover opens the reactions alone', (tester) async {
      await pump(tester, window: PaneWindow.desktop);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(bubble('Отправлю до обеда')));
      await tester.pumpAndSettle();

      final react = find.byTooltip(l10n.messageReact);
      expect(react, findsOneWidget);
      await tester.tap(react);
      await tester.pumpAndSettle();

      expect(find.text(l10n.moreReactions), findsNothing);
      expect(find.byTooltip(l10n.moreReactions), findsOneWidget);
      expect(find.text(l10n.messageCopy), findsNothing);
    }, variant: windows);
  });

  group('goldens', () {
    /// A golden drawn as on Windows: the desktop chrome — scrollbars, the
    /// composer's caret, the drop zone — is only there on a desktop.
    void desktopGolden(
      String description,
      Future<void> Function(WidgetTester tester) body,
    ) {
      testGoldens(description, (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        EditableText.debugDeterministicCursor = true;
        try {
          await body(tester);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      });
    }

    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final MapEntry(key: theme, value: dark)
          in chatGoldenThemes.entries) {
        final size = window == PaneWindow.phone ? 'phone' : 'desktop';

        desktopGolden('hover buttons beside a bubble, $size, $theme', (
          tester,
        ) async {
          await pump(tester, window: window, dark: dark);

          final mouse = await tester.createGesture(
            kind: PointerDeviceKind.mouse,
          );
          await mouse.addPointer(location: Offset.zero);
          addTearDown(mouse.removePointer);
          await mouse.moveTo(
            tester.getCenter(bubble('Заметки к релизу готовы?')),
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'chat_hover_actions_${size}_$theme',
          );
        });

        desktopGolden('the menu at the pointer, $size, $theme', (tester) async {
          await pump(tester, window: window, dark: dark);

          await tester.tapAt(
            tester.getCenter(find.text('Отправлю до обеда')),
            buttons: kSecondaryMouseButton,
            kind: PointerDeviceKind.mouse,
          );
          await tester.pumpAndSettle();

          await screenMatchesGolden(tester, 'chat_cursor_menu_${size}_$theme');
        });

        desktopGolden('files dragged over the chat, $size, $theme', (
          tester,
        ) async {
          await pump(tester, window: window, dark: dark);

          await TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .handlePlatformMessage(
                'desktop_drop',
                const StandardMethodCodec().encodeMethodCall(
                  // Over the chat itself: in two panes the left of the
                  // window is the list, which takes no files.
                  MethodCall('entered', <double>[
                    window.size.width - window.paneWidth / 2,
                    400,
                  ]),
                ),
                (_) {},
              );
          await tester.pumpAndSettle();

          await screenMatchesGolden(tester, 'chat_drop_zone_${size}_$theme');
        });
      }
    }
  });
}
