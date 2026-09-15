import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/chat/data/datasources/voice_local_store.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/voice_waveform.dart';
import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_waveform_bars.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';
  const messageId = 'b3f1c2d4-0000-4000-8000-000000000002';

  late AppLocalizations l10n;
  late InMemoryVoiceLocalStore store;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => store = InMemoryVoiceLocalStore());

  AttachmentEntity voice({String id = 'v1', int? duration = 65}) =>
      AttachmentEntity(
        id: id,
        messageId: messageId,
        chatId: chatId,
        uploaderId: 7,
        attachmentType: AttachmentType.voice,
        attachmentStatus: AttachmentStatus.success,
        url: null,
        urlExpiresIn: null,
        s3Key: 'chats/$chatId/$id/voice.ogg',
        mimeType: 'audio/ogg',
        originalFilename: 'voice.ogg',
        size: 4096,
        width: null,
        height: null,
        durationSeconds: duration,
        createdAt: DateTime(2026, 3, 1),
      );

  Future<void> pump(
    WidgetTester tester, {
    AttachmentEntity? attachment,
    bool isMine = false,
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [voiceLocalStoreProvider.overrideWithValue(store)],
        child: MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: VoicePlayer(
                attachment: attachment ?? voice(),
                messageId: messageId,
                foreground: const Color(0xFF111111),
                accent: const Color(0xFF2E7D32),
                authorId: 7,
                isMine: isMine,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('says who spoke, how long for, and draws the shape of it', (
    tester,
  ) async {
    await pump(tester);

    expect(find.byType(ChatAvatar), findsOneWidget);
    expect(find.byType(VoiceWaveformBars), findsOneWidget);
    // The server's `duration_seconds`, as m:ss.
    expect(find.text('1:05'), findsOneWidget);
  });

  testWidgets('draws the bars this device recorded when it has them', (
    tester,
  ) async {
    final recorded = VoiceWaveform.fromSamples([0.9, 0.2, 0.6, 0.1]);
    await store.writeWaveform('v1', recorded);

    await pump(tester);

    final bars = tester
        .widget<VoiceWaveformBars>(find.byType(VoiceWaveformBars))
        .bars;
    expect(bars, recorded.bars);
  });

  testWidgets('falls back to a stand-in for somebody else\'s recording', (
    tester,
  ) async {
    await pump(tester);

    final bars = tester
        .widget<VoiceWaveformBars>(find.byType(VoiceWaveformBars))
        .bars;
    expect(bars, VoiceWaveform.placeholder('v1').bars);
  });

  testWidgets('an incoming message nobody has played is marked unheard', (
    tester,
  ) async {
    await pump(tester);

    expect(find.bySemanticsLabel(l10n.voiceNotListened), findsOneWidget);
  });

  testWidgets('the mark goes once it has been heard', (tester) async {
    await store.markListened('v1');
    await pump(tester);

    expect(find.bySemanticsLabel(l10n.voiceNotListened), findsNothing);
  });

  testWidgets('an outgoing message never claims to know if it was heard', (
    tester,
  ) async {
    // Nothing in the API reports whether the other side listened
    // (api-docs §5.5), so our own bubbles carry no mark at all.
    await pump(tester, isMine: true);

    expect(find.bySemanticsLabel(l10n.voiceNotListened), findsNothing);
  });

  testWidgets('the speed control belongs to whatever is playing, not to '
      'every bubble', (tester) async {
    await pump(tester);

    expect(find.text('1x'), findsNothing);
  });

  testWidgets('a waveform with no playback loaded cannot be scrubbed', (
    tester,
  ) async {
    await pump(tester);

    final waveform = tester.widget<VoiceWaveformBars>(
      find.byType(VoiceWaveformBars),
    );
    expect(waveform.onSeek, isNull);
    expect(waveform.progress, 0);
  });

  testWidgets('a message the server never timed shows 0:00 rather than a gap', (
    tester,
  ) async {
    await pump(tester, attachment: voice(duration: null));
    expect(find.text('0:00'), findsOneWidget);
  });

  testWidgets('draws in the dark theme too', (tester) async {
    await pump(tester, dark: true);
    expect(tester.takeException(), isNull);
    expect(find.byType(VoiceWaveformBars), findsOneWidget);
  });
}
