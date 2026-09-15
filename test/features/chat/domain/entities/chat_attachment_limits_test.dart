import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';

/// The frame rule for video notes. Which side the cap is measured on is the
/// whole difference between an ordinary 480p capture being usable and being
/// rejected with `resolution_limit_exceeded` (api-docs §5.5), and nothing
/// downstream resizes anything — so the recorder picks a resolution by this
/// and the finished file is checked against it again.
///
/// The cap is read on the **short** side — confirmed against the backend,
/// since api-docs §5.5 says only "≤ 640 px". That is what lets an ordinary
/// Android 480p capture (720×480) through at all, and the failure mode for
/// getting it wrong is silent: `attachment_status: "error"` with the reason
/// kept server-side, after the message has been sent.
void main() {
  bool fits(int w, int h) => ChatAttachmentLimits.fitsVideoNoteFrame(w, h);

  test('the cap is 640', () {
    expect(ChatAttachmentLimits.maxVideoNoteResolutionPx, 640);
  });

  group('measured on the short side', () {
    test('a square frame at the cap passes', () {
      expect(fits(640, 640), isTrue);
    });

    test('one pixel over on the short side does not', () {
      expect(fits(641, 641), isFalse);
      expect(fits(720, 641), isFalse);
    });

    test('a long side well over the cap is fine on its own', () {
      // 720×480 is the ordinary Android 480p capture: over 640 lengthways,
      // 480 across, and perfectly acceptable.
      expect(fits(720, 480), isTrue);
      expect(fits(1920, 480), isTrue);
    });

    test('orientation does not change the answer', () {
      expect(fits(480, 720), fits(720, 480));
      expect(fits(720, 1280), fits(1280, 720));
    });

    test('a frame with no size at all is not a frame', () {
      expect(fits(0, 480), isFalse);
      expect(fits(640, 0), isFalse);
      expect(fits(-1, 480), isFalse);
    });
  });

  group('the square a note is shown as', () {
    int side(int w, int h) => ChatAttachmentLimits.videoNoteSquareSide(w, h);

    test('is the shorter side of the frame', () {
      expect(side(640, 480), 480);
      expect(side(480, 640), 480);
      expect(side(352, 288), 288);
    });

    test('never exceeds the cap, however large the capture', () {
      expect(side(1920, 1080), ChatAttachmentLimits.maxVideoNoteResolutionPx);
      expect(side(640, 640), 640);
    });

    test('is nothing at all for a frame with no size', () {
      expect(side(0, 480), 0);
      expect(side(-1, -1), 0);
    });
  });

  group('what the camera presets actually produce', () {
    test('480p passes on both platforms — which is why medium is tried '
        'first', () {
      expect(fits(640, 480), isTrue, reason: 'iOS medium');
      expect(fits(720, 480), isTrue, reason: 'Android medium');
    });

    test('720p does not, so there is nothing above medium to try', () {
      expect(fits(1280, 720), isFalse);
      expect(CameraVideoNoteRecorder.presets.first.name, 'medium');
      expect(CameraVideoNoteRecorder.presets, hasLength(2));
    });

    test('the fallback fits anywhere', () {
      expect(fits(352, 288), isTrue, reason: 'iOS low');
      expect(fits(320, 240), isTrue, reason: 'Android low');
      expect(CameraVideoNoteRecorder.presets.last.name, 'low');
    });
  });
}
