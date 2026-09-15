import 'dart:async';

import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_record_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_video_note_stage.dart';
import 'package:chatix/features/chat/presentation/widgets/video_note_lens_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../../helpers/chat_golden.dart';
import '../../../../../helpers/fakes/fake_video_note_recorder.dart';

/// The circle above the composer while a video note is being held down. It
/// takes no room at all when nothing is being recorded — the composer must
/// not jump by the height of a camera every time a thumb lands on the
/// button — and it says which of the three things is happening behind it.
void main() {
  late FakeVideoNoteRecorder recorder;
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  setUp(() => recorder = FakeVideoNoteRecorder(hasSecondCamera: true));

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    bool dark = false,
    bool start = true,
  }) async {
    final container = ProviderContainer(
      overrides: [
        videoNoteRecorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: chatGoldenTheme(dark: dark),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [ComposerVideoNoteStage()],
            ),
          ),
        ),
      ),
    );

    if (start) {
      await container.read(videoNoteRecordProvider.notifier).start();
      await tester.pumpAndSettle();
    } else {
      await tester.pumpAndSettle();
    }
    return container;
  }

  /// Closes the camera. The recorder's ticker runs on the tester's own
  /// clock, and a test that leaves it running fails on a pending timer
  /// before any tear-down gets a look in.
  Future<void> stop(ProviderContainer container) =>
      container.read(videoNoteRecordProvider.notifier).cancel();

  testWidgets('takes no room while nothing is being recorded', (tester) async {
    await pump(tester, start: false);

    expect(find.byType(VideoNoteLensView), findsNothing);
    expect(
      tester.getSize(find.byType(ComposerVideoNoteStage)).height,
      0,
      reason: 'the composer does not move until there is something to show',
    );
  });

  testWidgets('shows the camera in the circle it will be sent as', (
    tester,
  ) async {
    final container = await pump(tester);

    expect(find.byType(VideoNoteLensView), findsOneWidget);
    expect(
      tester.getSize(find.byType(VideoNoteLensView)),
      const Size(
        ComposerVideoNoteStage.diameter,
        ComposerVideoNoteStage.diameter,
      ),
    );

    await stop(container);
  });

  testWidgets('says a double tap turns the camera around, where there is a '
      'second one', (tester) async {
    final container = await pump(tester);

    expect(find.text(l10n.videoNoteDoubleTapToSwitch), findsOneWidget);

    await stop(container);
  });

  testWidgets('and says nothing of the sort on a phone with one camera', (
    tester,
  ) async {
    recorder.hasSecondCamera = false;
    final container = await pump(tester);

    expect(find.text(l10n.videoNoteDoubleTapToSwitch), findsNothing);

    await stop(container);
  });

  testWidgets('a double tap on the circle turns the camera around', (
    tester,
  ) async {
    final container = await pump(tester);

    await tester.tap(find.byType(VideoNoteLensView));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byType(VideoNoteLensView));
    await tester.pumpAndSettle();

    expect(recorder.lensSwitches, 1);
    expect(container.read(videoNoteRecordProvider).lens, VideoNoteLens.back);
    expect(recorder.isRecording, isTrue, reason: 'one file, not two');

    await stop(container);
  });

  testWidgets('waiting for the camera says so rather than going black', (
    tester,
  ) async {
    recorder.opening = Completer<void>();

    final container = ProviderContainer(
      overrides: [
        videoNoteRecorderFactoryProvider.overrideWithValue(() => recorder),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ComposerVideoNoteStage()),
        ),
      ),
    );

    unawaited(container.read(videoNoteRecordProvider.notifier).start());
    await tester.pump();

    expect(find.text(l10n.videoNoteOpeningCamera), findsOneWidget);
    expect(find.byType(VideoNoteLensView), findsNothing);

    recorder.opening!.complete();
    await tester.pumpAndSettle();
    await container.read(videoNoteRecordProvider.notifier).cancel();
    await tester.pumpAndSettle();
  });

  for (final entry in chatGoldenThemes.entries) {
    testGoldens('the recording circle on the ${entry.key} theme', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          videoNoteRecorderFactoryProvider.overrideWithValue(() => recorder),
        ],
      );
      addTearDown(container.dispose);

      await pumpChatGolden(
        tester,
        name: 'video_note_stage_${entry.key}',
        dark: entry.value,
        surfaceSize: const Size(260, 260),
        child: UncontrolledProviderScope(
          container: container,
          child: const ComposerVideoNoteStage(),
        ),
        interact: (tester) async {
          await container.read(videoNoteRecordProvider.notifier).start();
          await tester.pumpAndSettle();
        },
      );

      await stop(container);
    });
  }
}
