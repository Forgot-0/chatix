import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/presentation/providers/voice_playback_provider.dart';

/// The one video note the reader has turned the sound on for.
///
/// One, app-wide: notes play themselves as they scroll past, and a feed
/// where three of them are talking at once is not a feed anybody reads.
/// Turning the sound on for a note is therefore also turning it off for
/// whichever note had it — and for the voice message that was playing, which
/// is the same speaker and the same room.
class VideoNoteSoundController extends Notifier<String?> {
  @override
  String? build() => null;

  /// The attachment id of the note with sound, or null when every note in
  /// the feed is silent.
  void toggle(String attachmentId) {
    if (state == attachmentId) {
      state = null;
      return;
    }

    state = attachmentId;
    unawaited(ref.read(voicePlaybackProvider.notifier).pause());
  }

  void silence() {
    if (state != null) state = null;
  }
}

final videoNoteSoundProvider =
    NotifierProvider<VideoNoteSoundController, String?>(
      VideoNoteSoundController.new,
    );

/// How much of a note has to be on screen before it is worth playing, and
/// how little before it is stopped.
///
/// Two thresholds rather than one: a note parked exactly on a single line
/// would start and stop on every frame of a slow scroll, which is a
/// flickering picture and a stuttering speaker. [wasOnScreen] is what the
/// gap between them is for.
bool videoNoteIsOnScreen({
  required double visible,
  required bool wasOnScreen,
}) {
  if (visible >= videoNotePlayAbove) return true;
  if (visible <= videoNotePauseBelow) return false;
  return wasOnScreen;
}

/// Two thirds: a note half out of the viewport is not being watched.
const double videoNotePlayAbove = 0.66;
const double videoNotePauseBelow = 0.35;

/// Whether a note should be playing right now.
///
/// The one rule, in one place, so the reader's setting, the connection, the
/// scroll position, the tap and the full-screen viewer cannot each hold a
/// different opinion about the same note. Sound always wins over autoplay:
/// a note the reader deliberately turned the sound on for keeps playing on
/// a connection autoplay would not have started it on.
bool videoNoteShouldPlay({
  required bool onScreen,
  required bool hasSound,
  required bool autoplayAllowed,
  required bool handedOver,
}) {
  if (handedOver) return false;
  if (!onScreen) return false;
  return hasSound || autoplayAllowed;
}
