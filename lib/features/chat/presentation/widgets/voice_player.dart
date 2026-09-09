import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_url_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class VoicePlayer extends ConsumerStatefulWidget {
  const VoicePlayer({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.foreground,
    required this.accent,
  });

  final AttachmentEntity attachment;
  final String messageId;
  final Color foreground;
  final Color accent;

  @override
  ConsumerState<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends ConsumerState<VoicePlayer> {
  final AudioPlayer _player = AudioPlayer();

  bool _loaded = false;
  bool _failed = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  AttachmentRef get _ref => (
    chatId: widget.attachment.chatId,
    messageId: widget.messageId,
    attachmentId: widget.attachment.id,
  );

  Future<void> _toggle() async {
    if (_player.playing) {
      await _player.pause();
      return;
    }

    if (!_loaded) {
      final url = widget.attachment.url?.isNotEmpty == true
          ? widget.attachment.url!
          : await _resolveUrl();
      if (url == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }

      try {
        await _player.setUrl(url);
        _loaded = true;
      } catch (_) {
        if (mounted) setState(() => _failed = true);
        return;
      }
    }

    if (_player.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
    }
    await _player.play();
  }

  Future<String?> _resolveUrl() async {
    final result = await ref
        .read(getAttachmentDownloadUrlUseCaseProvider)
        .execute(_ref.chatId, _ref.messageId, _ref.attachmentId);
    return result.getRight().toNullable()?.url;
  }

  @override
  Widget build(BuildContext context) {
    final total =
        widget.attachment.durationSeconds != null &&
            widget.attachment.durationSeconds! > 0
        ? Duration(seconds: widget.attachment.durationSeconds!)
        : null;

    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;
        final duration = _player.duration ?? total ?? Duration.zero;
        final progress = duration.inMilliseconds == 0
            ? 0.0
            : (position.inMilliseconds / duration.inMilliseconds).clamp(
                0.0,
                1.0,
              );

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, stateSnapshot) {
                final playing = stateSnapshot.data?.playing ?? false;
                return IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _failed ? null : _toggle,
                  icon: Icon(
                    _failed
                        ? Icons.error_outline
                        : (playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill),
                    size: 34,
                    color: widget.foreground,
                  ),
                );
              },
            ),
            SizedBox(
              width: 132,
              height: 32,
              child: GestureDetector(
                onTapDown: (details) {
                  if (duration.inMilliseconds == 0) return;
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final fraction = (details.localPosition.dx / box.size.width)
                      .clamp(0.0, 1.0);
                  _player.seek(duration * fraction);
                },
                child: CustomPaint(
                  painter: _WaveformPainter(
                    seed: widget.attachment.id.hashCode,
                    progress: progress,
                    played: widget.accent,
                    remaining: widget.foreground.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _format(
                _player.playing || position > Duration.zero
                    ? position
                    : duration,
              ),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: widget.foreground.withValues(alpha: 0.75),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _format(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.seed,
    required this.progress,
    required this.played,
    required this.remaining,
  });

  final int seed;
  final double progress;
  final Color played;
  final Color remaining;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    const barWidth = 3.0;
    const gap = 2.0;
    final count = (size.width / (barWidth + gap)).floor();

    for (var i = 0; i < count; i++) {
      final height = size.height * (0.25 + rng.nextDouble() * 0.75);
      final x = i * (barWidth + gap);
      final isPlayed = i / count <= progress;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, (size.height - height) / 2, barWidth, height),
          const Radius.circular(2),
        ),
        Paint()..color = isPlayed ? played : remaining,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      old.seed != seed ||
      old.played != played ||
      old.remaining != remaining;
}

class RecordingWaveform extends StatelessWidget {
  const RecordingWaveform({
    super.key,
    required this.amplitude,
    required this.color,
  });

  final double amplitude;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: AnimatedContainer(
        duration: ChatixTheme.fastDuration,
        curve: ChatixTheme.curve,
        width: 6 + amplitude * 18,
        height: 6 + amplitude * 18,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
