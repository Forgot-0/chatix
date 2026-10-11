import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/video_poster_provider.dart';

/// A video's picture: its poster once there is one, and until then the dark
/// ground every video had before posters existed (see `VideoPoster`).
///
/// Fills its box. The feed, the viewer and the viewer's thumbnails all draw
/// a video through this, so one poster is made once and shows up everywhere
/// at the same moment.
class VideoPosterView extends ConsumerWidget {
  const VideoPosterView({
    super.key,
    required this.attachment,
    required this.messageId,
    this.fit = BoxFit.cover,
  });

  final AttachmentEntity attachment;
  final String messageId;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poster = ref.watch(
      videoPosterProvider(attachmentFileKey(attachment, messageId: messageId)),
    );

    final width = attachment.width;
    final height = attachment.height;

    return VideoPosterImage(
      file: poster,
      fit: fit,
      aspectRatio: width != null && height != null && height > 0
          ? width / height
          : null,
    );
  }
}

/// A poster [file] over the dark ground, or the ground alone while there is
/// none.
class VideoPosterImage extends StatelessWidget {
  const VideoPosterImage({
    super.key,
    required this.file,
    this.fit = BoxFit.cover,
    this.aspectRatio,
  });

  final File? file;
  final BoxFit fit;

  /// The video's width ÷ height when known, so the poster is decoded no
  /// bigger than its box needs — 48 px in the viewer's strip.
  final double? aspectRatio;

  @override
  Widget build(BuildContext context) {
    final file = this.file;
    if (file == null) return const VideoGround();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Under the picture while it decodes, and behind any letterboxing.
        const VideoGround(),
        LayoutBuilder(
          builder: (context, constraints) => Image.file(
            file,
            fit: fit,
            width: double.infinity,
            height: double.infinity,
            cacheWidth: _decodeWidth(context, constraints),
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  /// Wide enough to cover the box at this aspect ratio, and no wider; left
  /// to the full poster (at most `VideoPoster.maxWidth`) when either is
  /// unknown.
  int? _decodeWidth(BuildContext context, BoxConstraints constraints) {
    final ratio = aspectRatio;
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    if (ratio == null || !width.isFinite || !height.isFinite) return null;

    final needed = fit == BoxFit.cover
        ? math.max(width, height * ratio)
        : math.min(width, height * ratio);

    return (needed * MediaQuery.devicePixelRatioOf(context)).ceil();
  }
}

/// What a video is drawn on while there is no frame to show: dark in both
/// themes, because that is what reads as "video".
class VideoGround extends StatelessWidget {
  const VideoGround({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppPalette.videoGroundTop, AppPalette.videoGroundBottom],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

/// The round play badge over a video's poster. Over a picture the glyph
/// needs a plate of its own: a white outline vanishes into a white sky.
class VideoPlayBadge extends StatelessWidget {
  const VideoPlayBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ChatLayout.videoPlayBadgeSize,
      height: ChatLayout.videoPlayBadgeSize,
      decoration: const BoxDecoration(
        color: AppPalette.mediaScrim,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        color: AppPalette.onMediaScrim,
        size: ChatLayout.videoPlayGlyphSize,
      ),
    );
  }
}
