import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/haptics.dart';

class _RecordingDriver implements HapticDriver {
  final List<HapticStrength> fired = <HapticStrength>[];

  @override
  void impact(HapticStrength strength) => fired.add(strength);
}

void main() {
  late _RecordingDriver driver;

  setUp(() {
    driver = _RecordingDriver();
    AppHaptics.reset();
    AppHaptics.driver = driver;
  });

  tearDown(AppHaptics.reset);

  group('the vocabulary', () {
    test('sending is the lightest thing the app does', () {
      AppHaptics.messageSent();
      expect(driver.fired, [HapticStrength.light]);
    });

    test('a reaction and a gesture threshold are both ticks', () {
      AppHaptics.reactionToggled();
      AppHaptics.gestureThreshold();

      expect(driver.fired, [
        HapticStrength.selection,
        HapticStrength.selection,
      ]);
    });

    test('a recording starts with a knock and locks with one', () {
      AppHaptics.recordingStarted();
      AppHaptics.recordingLocked();

      expect(driver.fired, [HapticStrength.medium, HapticStrength.medium]);
    });

    test('the two things nobody asked for are the heavy ones', () {
      AppHaptics.recordingLimit();
      AppHaptics.error();

      expect(driver.fired, [HapticStrength.heavy, HapticStrength.heavy]);
    });

    test('throwing a recording away is gentler than making one', () {
      AppHaptics.recordingCancelled();
      expect(driver.fired, [HapticStrength.light]);
    });

    test('a long press is the same knock as a recording starting', () {
      AppHaptics.longPress();
      expect(driver.fired, [HapticStrength.medium]);
    });
  });

  group('the global switch', () {
    test('nothing fires while it is off', () {
      AppHaptics.setEnabled(false);

      AppHaptics.messageSent();
      AppHaptics.error();
      AppHaptics.longPress();

      expect(driver.fired, isEmpty);
    });

    test('turning it back on resumes without a restart', () {
      AppHaptics.setEnabled(false);
      AppHaptics.messageSent();
      AppHaptics.setEnabled(true);
      AppHaptics.messageSent();

      expect(driver.fired, [HapticStrength.light]);
    });

    test('it defaults to on', () {
      expect(AppHaptics.enabled, isTrue);
    });
  });

  group('failures are felt', () {
    testWidgets('a failure snackbar buzzes, a quiet one does not', (
      tester,
    ) async {
      late BuildContext context;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (inner) {
                context = inner;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      AppSnackbar.quiet(context, 'saved');
      await tester.pump();
      expect(driver.fired, isEmpty);

      AppSnackbar.failure(context, 'did not save');
      await tester.pump();
      expect(driver.fired, [HapticStrength.heavy]);
    });

    testWidgets('a snackbar outside a messenger neither draws nor buzzes', (
      tester,
    ) async {
      late BuildContext context;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (inner) {
              context = inner;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      AppSnackbar.failure(context, 'nowhere to say it');
      await tester.pump();

      expect(driver.fired, isEmpty);
    });
  });
}
