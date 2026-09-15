import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/feedback/progress_ring.dart';
import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/presentation/widgets/composer/composer_send_button.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../../helpers/fakes/fake_video_note_recorder.dart';
import '../../providers/voice_recorder_test.dart' show FakeVoiceRecorder;

/// One control doing three jobs. Which one it is doing has to be readable at
/// a glance, and slow mode has to hold it rather than let a message go out
/// and come back 429 (api-docs §5.2).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required ComposerAction action,
    bool enabled = true,
    SlowMode slowMode = SlowMode.off,
    VoidCallback? onSend,
    void Function(VoiceRecording)? onVoiceRecorded,
    void Function(VideoNoteTake)? onVideoNoteRecorded,
    FakeVideoNoteRecorder? recorder,
    FakeVoiceRecorder? microphone,
    bool settle = true,
    DateTime Function()? clock,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (recorder != null)
            videoNoteRecorderFactoryProvider.overrideWithValue(() => recorder),
          if (microphone != null)
            voiceRecorderProvider.overrideWithValue(microphone),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ComposerSendButton(
                action: action,
                enabled: enabled,
                slowMode: slowMode,
                onSend: onSend,
                onVoiceRecorded: onVoiceRecorded ?? (_) {},
                onVideoNoteRecorded: onVideoNoteRecorded,
                clock: clock ?? ComposerSendButton.systemClock,
              ),
            ),
          ),
        ),
      ),
    );

    // A running countdown rebuilds once a second forever, and pumpAndSettle
    // would sit through the whole wait before returning.
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  /// Which icons are drawn at all, and how strongly. Mid-morph two of them
  /// are on screen at once, which is the point.
  Map<IconData, double> iconsOn(WidgetTester tester) {
    final result = <IconData, double>{};

    for (final element in find.byType(Icon).evaluate()) {
      final icon = element.widget as Icon;
      final opacity = tester.widgetList<Opacity>(
        find.ancestor(of: find.byWidget(icon), matching: find.byType(Opacity)),
      );
      result[icon.icon!] = opacity.isEmpty ? 1 : opacity.first.opacity;
    }
    return result;
  }

  group('which shape it wears', () {
    testWidgets('nothing typed: the microphone', (tester) async {
      await pump(tester, action: ComposerAction.record, enabled: false);

      expect(iconsOn(tester)[Icons.mic_none_rounded], 1);
      expect(iconsOn(tester).containsKey(Icons.send_rounded), isFalse);
    });

    testWidgets('something typed: the plane', (tester) async {
      await pump(tester, action: ComposerAction.send);

      expect(iconsOn(tester)[Icons.send_rounded], 1);
      expect(iconsOn(tester).containsKey(Icons.mic_none_rounded), isFalse);
    });

    testWidgets('editing: the tick', (tester) async {
      await pump(tester, action: ComposerAction.save);

      expect(iconsOn(tester)[Icons.check_rounded], 1);
    });
  });

  testWidgets('changing job morphs rather than swapping', (tester) async {
    await pump(tester, action: ComposerAction.record, enabled: false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ComposerSendButton(
                action: ComposerAction.send,
                enabled: true,
                slowMode: SlowMode.off,
                onSend: () {},
                onVoiceRecorded: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    // Halfway through, both icons are on screen and neither is at full
    // strength — a swap would show exactly one of them on every frame.
    await tester.pump(const Duration(milliseconds: 110));
    final midway = iconsOn(tester);

    expect(midway[Icons.mic_none_rounded], isNotNull);
    expect(midway[Icons.send_rounded], isNotNull);
    expect(midway[Icons.mic_none_rounded], lessThan(1));
    expect(midway[Icons.send_rounded], lessThan(1));

    await tester.pumpAndSettle();
    expect(iconsOn(tester)[Icons.send_rounded], 1);
  });

  group('sending', () {
    testWidgets('a tap sends when there is something to send', (tester) async {
      var sent = 0;
      await pump(tester, action: ComposerAction.send, onSend: () => sent++);

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pump();

      expect(sent, 1);
    });

    testWidgets('a disabled button does nothing', (tester) async {
      var sent = 0;
      await pump(
        tester,
        action: ComposerAction.send,
        enabled: false,
        onSend: () => sent++,
      );

      await tester.tap(find.byType(ComposerSendButton), warnIfMissed: false);
      await tester.pump();

      expect(sent, 0);
    });
  });

  group('slow mode', () {
    SlowMode waiting(int seconds) => SlowMode(
      interval: Duration(seconds: seconds),
      sendAllowedAt: DateTime.now().add(Duration(seconds: seconds)),
    );

    testWidgets('counts down in place of the icon', (tester) async {
      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: waiting(9),
        settle: false,
      );

      expect(find.text('9'), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('a long wait is shown as minutes and seconds', (tester) async {
      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: waiting(90),
        settle: false,
      );

      expect(find.text('1:30'), findsOneWidget);
    });

    testWidgets('the number ticks down on its own', (tester) async {
      // The button reads the wall clock, which a test cannot move; this is
      // the same clock, moved by hand.
      var now = DateTime.utc(2026, 3, 1, 12);

      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: SlowMode(
          interval: const Duration(seconds: 5),
          sendAllowedAt: now.add(const Duration(seconds: 5)),
        ),
        clock: () => now,
        settle: false,
      );

      expect(find.text('5'), findsOneWidget);

      now = now.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('nothing goes out while it runs', (tester) async {
      var sent = 0;
      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: waiting(9),
        onSend: () => sent++,
        settle: false,
      );

      await tester.tap(find.byType(ComposerSendButton), warnIfMissed: false);
      await tester.pump();

      expect(sent, 0);
    });

    testWidgets('and the button comes back once the wait is over', (
      tester,
    ) async {
      var sent = 0;
      var now = DateTime.utc(2026, 3, 1, 12);

      await pump(
        tester,
        action: ComposerAction.send,
        slowMode: SlowMode(
          interval: const Duration(seconds: 1),
          sendAllowedAt: now.add(const Duration(seconds: 1)),
        ),
        clock: () => now,
        onSend: () => sent++,
        settle: false,
      );

      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pump();

      expect(sent, 1);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });
  });

  testWidgets('holding the microphone records — the tooltip does not take the '
      'press', (tester) async {
    // A tooltip installs its own long-press recogniser inside the button's,
    // and an inner recogniser wins the arena. Left alone it would swallow
    // every hold and the microphone would never open.
    final microphone = FakeVoiceRecorder();
    addTearDown(microphone.dispose);

    await pump(
      tester,
      action: ComposerAction.record,
      enabled: false,
      microphone: microphone,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ComposerSendButton)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(microphone.startCount, 1);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  group('the microphone is two recorders', () {
    testWidgets('a tap swaps it for the camera, and back', (tester) async {
      await pump(
        tester,
        action: ComposerAction.record,
        enabled: false,
        onVideoNoteRecorded: (_) {},
      );

      expect(iconsOn(tester)[Icons.mic_none_rounded], 1);

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pumpAndSettle();

      expect(iconsOn(tester)[Icons.videocam_outlined], 1);
      expect(iconsOn(tester).containsKey(Icons.mic_none_rounded), isFalse);

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pumpAndSettle();

      expect(iconsOn(tester)[Icons.mic_none_rounded], 1);
    });

    testWidgets('there is nothing to swap to where video notes are not on '
        'offer', (tester) async {
      await pump(tester, action: ComposerAction.record, enabled: false);

      await tester.tap(find.byType(ComposerSendButton), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(iconsOn(tester)[Icons.mic_none_rounded], 1);
    });

    testWidgets('a tap with something to send still sends', (tester) async {
      var sent = 0;
      await pump(
        tester,
        action: ComposerAction.send,
        onSend: () => sent++,
        onVideoNoteRecorded: (_) {},
      );

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pumpAndSettle();

      expect(sent, 1);
      expect(iconsOn(tester)[Icons.send_rounded], 1);
    });
  });

  group('holding the camera', () {
    late FakeVideoNoteRecorder recorder;
    late List<VideoNoteTake> taken;

    setUp(() {
      recorder = FakeVideoNoteRecorder();
      taken = <VideoNoteTake>[];
    });

    /// Puts the button in its camera shape and holds it down.
    Future<void> hold(WidgetTester tester) async {
      await pump(
        tester,
        action: ComposerAction.record,
        enabled: false,
        recorder: recorder,
        onVideoNoteRecorded: taken.add,
      );

      await tester.tap(find.byType(ComposerSendButton));
      await tester.pumpAndSettle();

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(ComposerSendButton)),
      );
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      addTearDown(() async {
        if (recorder.isRecording) await gesture.up();
      });
      _gesture = gesture;
    }

    testWidgets('opens the camera and counts its sixty seconds on a ring', (
      tester,
    ) async {
      await hold(tester);

      expect(recorder.starts, 1);
      expect(find.byType(ProgressRing), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      final ring = tester.widget<ProgressRing>(find.byType(ProgressRing));
      expect(ring.progress, closeTo(0.5, 0.05));

      await _gesture!.up();
      await tester.pumpAndSettle();
    });

    testWidgets('letting go hands the take back', (tester) async {
      await hold(tester);
      await tester.pump(const Duration(seconds: 2));

      await _gesture!.up();
      await tester.pumpAndSettle();

      expect(taken, hasLength(1));
      expect(recorder.stops, 1);
      expect(recorder.disposals, 1, reason: 'the camera goes back');
    });

    testWidgets('sliding left and letting go throws it away', (tester) async {
      await hold(tester);

      // Far past the 90 logical pixels that commit the cancel.
      await _gesture!.moveBy(const Offset(-140, 0));
      await tester.pump();
      await _gesture!.up();
      await tester.pumpAndSettle();

      expect(taken, isEmpty);
      expect(recorder.cancels, 1);
      expect(recorder.stops, 0);
    });

    testWidgets('a camera that will not open says so instead', (tester) async {
      recorder.readiness = VideoNoteReadiness.noCamera;
      await hold(tester);

      expect(find.byIcon(Icons.videocam_off_outlined), findsOneWidget);
      expect(recorder.starts, 0);
    });
  });
}

/// The gesture the current `holding the camera` test is driving. Held out of
/// the group's closure so the assertions can reach it after the hold has
/// started.
TestGesture? _gesture;