import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';

/// A camera that answers from fields instead of hardware.
///
/// Shared by everything that drives the video-note recorder, so the sheet,
/// the composer's hold and the controller are all tested against one idea of
/// what a camera does.
class FakeVideoNoteRecorder implements VideoNoteRecorder {
  FakeVideoNoteRecorder({
    this.readiness = VideoNoteReadiness.ready,
    VideoNoteTake? take,
    this.hasSecondCamera = false,
  }) : take = take ?? usable();

  VideoNoteReadiness readiness;

  /// What [stop] hands back. Null stands for a take too short to keep.
  VideoNoteTake? take;

  /// Whether this fake device has a second camera to turn to.
  bool hasSecondCamera;

  /// Makes [prepare] take its time, the way a real camera does, so a thumb
  /// can come up while it is still opening.
  Completer<void>? opening;

  bool _recording = false;
  int starts = 0;
  int stops = 0;
  int cancels = 0;
  int disposals = 0;
  int lensSwitches = 0;

  /// A take the composer would accept.
  static VideoNoteTake usable() => const VideoNoteTake(
    duration: Duration(seconds: 4),
    side: 480,
    upload: AttachmentUploadRequestEntity.videoNote(
      filename: 'note.mp4',
      mimeType: 'video/mp4',
      fileSize: 2048,
      filePath: '/tmp/note.mp4',
    ),
  );

  @override
  Future<VideoNoteReadiness> prepare() async {
    await opening?.future;
    return readiness;
  }

  @override
  Widget buildPreview() => const ColoredBox(color: Color(0xFF223344));

  @override
  double get aspectRatio => 4 / 3;

  @override
  VideoNoteLens lens = VideoNoteLens.front;

  @override
  bool get canSwitchLens => hasSecondCamera;

  @override
  Future<void> switchLens() async {
    if (!hasSecondCamera) return;
    lensSwitches++;
    lens = lens == VideoNoteLens.front
        ? VideoNoteLens.back
        : VideoNoteLens.front;
  }

  @override
  bool get isRecording => _recording;

  @override
  Future<void> start() async {
    starts++;
    _recording = readiness == VideoNoteReadiness.ready;
  }

  @override
  Future<VideoNoteTake?> stop() async {
    stops++;
    _recording = false;
    return take;
  }

  @override
  Future<void> cancel() async {
    cancels++;
    _recording = false;
  }

  @override
  Future<void> dispose() async => disposals++;
}
