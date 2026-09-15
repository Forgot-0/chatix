import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/video_note_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../../helpers/chat_golden.dart';
import '../../../../../helpers/fakes/fake_video_note_recorder.dart';

/// The recorder is the client's own because the server will not resize
/// anything: `video_note` is capped at 640 px and 60 s (api-docs §5.5), and
/// a capture over either is thrown away with nothing but
/// `attachment_status: "error"` to show for it.
void main() {
  late FakeVideoNoteRecorder recorder;
  VideoNoteTake? result;
  var returned = false;

  setUp(() {
    recorder = FakeVideoNoteRecorder();
    result = null;
    returned = false;
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          videoNoteRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await VideoNoteSheet.show(context);
                  returned = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapShutter(WidgetTester tester) async {
    await tester.tap(find.byType(InkResponse));
    await tester.pumpAndSettle();
  }

  group('opening', () {
    testWidgets('shows the camera in the circle it will be sent as', (
      tester,
    ) async {
      await open(tester);

      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.text('Tap to record'), findsOneWidget);
    });

    testWidgets('a refused grant explains itself instead of a black circle', (
      tester,
    ) async {
      recorder.readiness = VideoNoteReadiness.denied;
      await open(tester);

      expect(
        find.text('Allow camera and microphone access to record a video note'),
        findsOneWidget,
      );
      expect(find.byType(ClipOval), findsNothing);
    });

    testWidgets('a device with no camera says so', (tester) async {
      recorder.readiness = VideoNoteReadiness.noCamera;
      await open(tester);

      expect(
        find.text('This device has no camera to record with'),
        findsOneWidget,
      );
    });

    testWidgets('a camera that only records above the cap says which cap', (
      tester,
    ) async {
      // Nothing downstream will resize it, so there is no take worth making.
      recorder.readiness = VideoNoteReadiness.tooLarge;
      await open(tester);

      expect(
        find.textContaining(
          '${ChatAttachmentLimits.maxVideoNoteResolutionPx} px',
        ),
        findsOneWidget,
      );
    });
  });

  group('recording', () {
    testWidgets('the shutter starts it and the clock runs', (tester) async {
      await open(tester);
      await tapShutter(tester);

      expect(recorder.starts, 1);
      expect(find.text('0:00'), findsOneWidget);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('0:02'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('tapping again sends the take back', (tester) async {
      await open(tester);
      await tapShutter(tester);
      await tester.pump(const Duration(seconds: 2));
      await tapShutter(tester);

      expect(recorder.stops, 1);
      expect(returned, isTrue);
      expect(result?.upload.attachmentType, AttachmentType.videoNote);
    });

    testWidgets('it stops itself at the 60 s the API allows', (tester) async {
      await open(tester);
      await tapShutter(tester);

      await tester.pump(
        const Duration(
          seconds: ChatAttachmentLimits.maxVideoNoteDurationSeconds,
        ),
      );
      await tester.pumpAndSettle();

      expect(recorder.stops, 1);
      expect(result, isNotNull);
    });

    testWidgets('a take too short to keep holds the sheet open', (
      tester,
    ) async {
      recorder.take = null;
      await open(tester);

      await tapShutter(tester);
      await tapShutter(tester);

      // Losing the camera over a mis-tap would be the wrong answer.
      expect(returned, isFalse);
      expect(find.text('Nothing was recorded'), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
    });

    testWidgets('and can be tried again from there', (tester) async {
      recorder.take = null;
      await open(tester);
      await tapShutter(tester);
      await tapShutter(tester);

      recorder.take = FakeVideoNoteRecorder.usable();
      await tapShutter(tester);
      await tester.pump(const Duration(seconds: 1));
      await tapShutter(tester);

      expect(result, isNotNull);
    });
  });

  group('leaving', () {
    testWidgets('the cross closes it with nothing recorded', (tester) async {
      await open(tester);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets('the camera is released with the sheet', (tester) async {
      // Otherwise the recording indicator stays on with nothing on screen
      // to explain it.
      await open(tester);
      expect(recorder.disposals, 0);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(recorder.disposals, 1);
    });

    testWidgets('a recording in progress is thrown away, not sent', (
      tester,
    ) async {
      await open(tester);
      await tapShutter(tester);
      await tester.pump(const Duration(seconds: 3));

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(recorder.cancels, 1);
      expect(recorder.stops, 0);
      expect(result, isNull);
    });
  });

  group('goldens', () {
    for (final entry in chatGoldenThemes.entries) {
      testGoldens('the video note recorder on the ${entry.key} theme', (
        tester,
      ) async {
        await tester.pumpWidgetBuilder(
          ProviderScope(
            overrides: [
              videoNoteRecorderFactoryProvider.overrideWithValue(
                () => recorder,
              ),
            ],
            child: const Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: VideoNoteSheet(),
              ),
            ),
          ),
          wrapper: materialAppWrapper(
            theme: chatGoldenTheme(dark: entry.value),
            localizations: AppLocalizations.localizationsDelegates,
          ),
          surfaceSize: const Size(380, 520),
        );
        await tester.pumpAndSettle();

        await screenMatchesGolden(tester, 'video_note_${entry.key}');
      });
    }
  });
}
