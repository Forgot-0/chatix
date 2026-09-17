import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/utils/call_layout.dart';

CallParticipant participant(
  String identity, {
  bool isLocal = false,
  bool isSpeaking = false,
  double audioLevel = 0,
}) => CallParticipant(
  identity: identity,
  userId: int.tryParse(identity),
  name: 'User $identity',
  isLocal: isLocal,
  isSpeaking: isSpeaking,
  audioLevel: audioLevel,
  isMicrophoneEnabled: true,
  isCameraEnabled: false,
  videoTrack: null,
);

void main() {
  group('callGridFor', () {
    test('one participant fills the screen', () {
      for (final landscape in [true, false]) {
        final spec = callGridFor(count: 1, isLandscape: landscape);
        expect(spec.columns, 1);
        expect(spec.rows, 1);
        expect(spec.isScrollable, isFalse);
      }
    });

    test('an empty room still asks for a single cell', () {
      final spec = callGridFor(count: 0, isLandscape: false);
      expect(spec.columns, 1);
      expect(spec.rows, 1);
    });

    test('two split along the long axis', () {
      final portrait = callGridFor(count: 2, isLandscape: false);
      expect(portrait.columns, 1);
      expect(portrait.rows, 2);

      final landscape = callGridFor(count: 2, isLandscape: true);
      expect(landscape.columns, 2);
      expect(landscape.rows, 1);
    });

    test('three and four take a 2x2, in either orientation', () {
      for (final count in [3, 4]) {
        for (final landscape in [true, false]) {
          final spec = callGridFor(count: count, isLandscape: landscape);
          expect(spec.columns, 2, reason: 'count $count');
          expect(spec.rows, 2, reason: 'count $count');
          expect(spec.isScrollable, isFalse);
        }
      }
    });

    test('five and up scroll, wider in landscape', () {
      final portrait = callGridFor(count: 5, isLandscape: false);
      expect(portrait.columns, 2);
      expect(portrait.isScrollable, isTrue);

      final landscape = callGridFor(count: 9, isLandscape: true);
      expect(landscape.columns, 3);
      expect(landscape.isScrollable, isTrue);
    });
  });

  group('shouldFloatSelfPreview', () {
    test('floats only with the camera on and company in the room', () {
      expect(
        shouldFloatSelfPreview(isCameraEnabled: true, participantCount: 2),
        isTrue,
      );
      expect(
        shouldFloatSelfPreview(isCameraEnabled: true, participantCount: 1),
        isFalse,
      );
      expect(
        shouldFloatSelfPreview(isCameraEnabled: false, participantCount: 4),
        isFalse,
      );
    });
  });

  group('callGridParticipants', () {
    final people = [
      participant('1', isLocal: true),
      participant('2'),
      participant('3'),
    ];

    test('keeps everybody when the preview stays in the grid', () {
      expect(
        callGridParticipants(people, selfPreviewFloats: false),
        equals(people),
      );
    });

    test('drops the local tile once the preview floats', () {
      final tiles = callGridParticipants(people, selfPreviewFloats: true);
      expect(tiles.map((p) => p.identity), ['2', '3']);
    });

    test('never empties the grid to float a lone local participant', () {
      final alone = [participant('1', isLocal: true)];
      expect(
        callGridParticipants(alone, selfPreviewFloats: true),
        equals(alone),
      );
    });
  });

  group('callFocusedParticipant', () {
    test('returns null for an empty room', () {
      expect(callFocusedParticipant(const []), isNull);
    });

    test('prefers the pin over everything else', () {
      final people = [
        participant('1', isLocal: true),
        participant('2', isSpeaking: true, audioLevel: 0.9),
        participant('3'),
      ];
      expect(
        callFocusedParticipant(people, pinnedIdentity: '3')?.identity,
        '3',
      );
    });

    test('falls through to the loudest speaker', () {
      final people = [
        participant('1', isLocal: true),
        participant('2', isSpeaking: true, audioLevel: 0.2),
        participant('3', isSpeaking: true, audioLevel: 0.8),
      ];
      expect(callFocusedParticipant(people)?.identity, '3');
    });

    test('an unknown pin does not win over a live speaker', () {
      final people = [
        participant('1', isLocal: true),
        participant('2', isSpeaking: true, audioLevel: 0.4),
      ];
      expect(
        callFocusedParticipant(people, pinnedIdentity: 'gone')?.identity,
        '2',
      );
    });

    test('with nobody speaking it picks a remote participant', () {
      final people = [participant('1', isLocal: true), participant('2')];
      expect(callFocusedParticipant(people)?.identity, '2');
    });

    test('alone, it settles for the local participant', () {
      final people = [participant('1', isLocal: true)];
      expect(callFocusedParticipant(people)?.identity, '1');
    });
  });
}
