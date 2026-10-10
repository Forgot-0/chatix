import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/message_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/message_reply_quote.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';
import '../../../../helpers/test_photos.dart';

void main() {
  late Directory dir;
  late File photo;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('reply_quote_test');
    photo = TestPhotos.write(dir, name: 'p', width: 60, height: 60);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  final original = MessageEntity(
    id: 'm0',
    chatId: 'c',
    seq: 1,
    authorId: 42,
    type: MessageType.text,
    content: null,
    replyToId: null,
    forwardedFromChatId: null,
    forwardedFromMessageId: null,
    forwardedFromAuthorId: null,
    isEdited: false,
    createdAt: DateTime(2026, 10, 10, 9),
    attachments: [
      AttachmentEntity(
        id: 'a1',
        messageId: 'm0',
        chatId: 'c',
        uploaderId: 42,
        attachmentType: AttachmentType.image,
        attachmentStatus: AttachmentStatus.success,
        url: null,
        urlExpiresIn: null,
        s3Key: 'chats/c/a1/p.png',
        mimeType: 'image/png',
        originalFilename: 'p.png',
        size: 100,
        width: 60,
        height: 60,
        durationSeconds: null,
        createdAt: DateTime(2026, 10, 10, 9),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, Future<File?> Function() cache) async {
    await tester.pumpWidget(
      ProviderScope(
        // A failed fetch is answered at once rather than after Riverpod's
        // retries, which is what is under test.
        retry: (_, _) => null,
        overrides: [
          autoAttachmentFileProvider.overrideWith((ref, key) => cache()),
        ],
        child: MaterialApp(
          theme: chatGoldenTheme(dark: false),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: MessageReplyQuote(
                original: original,
                accent: Colors.indigo,
                foreground: Colors.black54,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the picture is 36 px, cut at 4, and set off from the rule', (
    tester,
  ) async {
    await pump(tester, () async => photo);

    final thumbnail = find.byType(AttachmentImage);
    final quote = tester.getRect(find.byType(MessageReplyQuote));
    final box = tester.getRect(thumbnail);

    expect(box.size, const Size.square(ChatLayout.replyThumbnailSize));
    // The rule is 3 px; the picture keeps its inset beyond it.
    expect(
      box.left - quote.left,
      greaterThanOrEqualTo(3 + ChatLayout.replyThumbnailInset),
    );
    expect(
      tester.widget<AttachmentImage>(thumbnail).borderRadius,
      BorderRadius.circular(ChatLayout.replyThumbnailRadius),
    );
  });

  testWidgets('a picture that will not come shows what it was', (tester) async {
    await pump(tester, () async => throw const FileSystemException('gone'));
    await tester.pump();

    expect(find.byType(AttachmentImageFailure), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AttachmentImage),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
  });

  testWidgets('one held back by the settings does too, not a "tap" notice', (
    tester,
  ) async {
    await pump(tester, () async => null);
    await tester.pump();

    expect(find.byType(AttachmentTapToDownload), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AttachmentImage),
        matching: find.byType(Icon),
      ),
      findsOneWidget,
    );
  });
}
