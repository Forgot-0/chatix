import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/progress_ring.dart';
import 'package:chatix/features/chat/data/datasources/video_note_recorder.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
import 'package:chatix/features/chat/presentation/providers/video_note_record_provider.dart';
import 'package:chatix/features/chat/presentation/providers/voice_recorder_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the one button on the right does right now.
enum ComposerAction {
  /// Nothing typed and nothing staged: hold to record a voice message.
  record,

  /// Something to send.
  send,

  /// An edit in the box: commit it.
  save,
}

/// The composer's single right-hand control.
///
/// One button for three jobs, because that is what the space is worth — and
/// because a control that changes shape reads as the same control doing
/// something else, where swapping widgets reads as one disappearing and
/// another arriving. The icons cross-fade through a shared rotation and the
/// fill grows behind them, so "nothing typed" turning into "ready to send"
/// is one continuous movement.
///
/// While slow mode holds a message back (api-docs §5.2) the button keeps its
/// shape and shows the seconds instead, counting down in place.
///
/// In its recording shape it is two buttons in one: a tap swaps the
/// microphone for the camera and back, and a hold records whichever is
/// showing. A video note counts its sixty seconds (api-docs §5.5) on a ring
/// around the button itself, where the thumb already is.
class ComposerSendButton extends ConsumerStatefulWidget {
  const ComposerSendButton({
    super.key,
    required this.action,
    required this.enabled,
    required this.slowMode,
    this.onSend,
    this.onVoiceRecorded,
    this.onVideoNoteRecorded,
    this.clock = systemClock,
  });

  final ComposerAction action;

  /// False while the message is unsendable for a reason of its own — empty,
  /// past the character cap, or already on its way.
  final bool enabled;

  final SlowMode slowMode;

  final VoidCallback? onSend;

  /// Null where voice messages are not on offer; the button then never takes
  /// the [ComposerAction.record] shape.
  final void Function(VoiceRecording recording)? onVoiceRecorded;

  /// Null where video notes are not on offer; the button then has nothing to
  /// swap to and stays a microphone.
  final void Function(VideoNoteTake take)? onVideoNoteRecorded;

  /// Where "now" comes from.
  ///
  /// The countdown is derived from the wall clock rather than counted down
  /// tick by tick, so a phone that was asleep through the wait comes back to
  /// the right number. A test cannot move the wall clock, hence the seam.
  final DateTime Function() clock;

  static DateTime systemClock() => DateTime.now();

  static const double diameter = 44;

  @override
  ConsumerState<ComposerSendButton> createState() => _ComposerSendButtonState();
}

class _ComposerSendButtonState extends ConsumerState<ComposerSendButton> {
  /// How far the thumb must travel from where it started to cancel or lock a
  /// recording — the same two gestures the rest of the world uses.
  static const double _cancelAt = 90;
  static const double _lockAt = 60;

  /// Below this the drag is treated as vertical and the cancel slide is left
  /// alone, so reaching for the lock does not also start throwing the
  /// recording away.
  static const double _axisBias = 1.4;

  Offset _origin = Offset.zero;

  /// Redraws the countdown once a second, and only while there is one.
  Timer? _tick;
  late DateTime _now = widget.clock();

  VoiceRecordController get _voice => ref.read(voiceRecordProvider.notifier);

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(ComposerSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.slowMode != oldWidget.slowMode) _syncTicker();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _syncTicker() {
    _now = widget.clock();

    final waiting = widget.slowMode.isWaitingAt(_now);
    if (!waiting) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick != null) return;

    _tick = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() => _now = widget.clock());
      if (!widget.slowMode.isWaitingAt(_now)) {
        timer.cancel();
        _tick = null;
      }
    });
  }

  VideoNoteRecordController get _note =>
      ref.read(videoNoteRecordProvider.notifier);

  Future<void> _finishRecording() async {
    final recording = await _voice.stop();
    if (recording != null) widget.onVoiceRecorded?.call(recording);
  }

  Future<void> _finishNote() async {
    final take = await _note.stop();
    if (take != null) widget.onVideoNoteRecorded?.call(take);
  }

  /// The two gestures that start from the same point: left throws the take
  /// away, up leaves the hands free. Shared by both recorders because they
  /// are the same thumb doing the same thing.
  void _onDrag(Offset position, {required bool isVideoNote}) {
    final delta = position - _origin;
    final up = -delta.dy;
    final left = -delta.dx;

    // Up wins when the thumb is clearly going up: the two gestures start
    // from the same point and a diagonal has to mean one thing.
    if (up > _lockAt && up > left * _axisBias) {
      isVideoNote ? _note.lock() : _voice.lock();
      return;
    }

    final progress = left / _cancelAt;
    isVideoNote
        ? _note.updateDrag(cancelProgress: progress)
        : _voice.updateDrag(cancelProgress: progress);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final voice = ref.watch(voiceRecordProvider);
    final note = ref.watch(videoNoteRecordProvider);
    final secondsLeft = widget.slowMode.secondsLeftAt(_now);

    // Mid-recording the button is no longer a shape-shifter: it is the one
    // control that ends the recording, and a locked recording gets a bin
    // beside it.
    if (voice.stage == VoiceRecordStage.denied) {
      return IconButton(
        tooltip: l10n.voicePermissionDenied,
        icon: Icon(Icons.mic_off_outlined, color: chatix.danger),
        onPressed: _voice.dismissDenied,
      );
    }

    if (note.stage == VideoNoteStage.unavailable) {
      return IconButton(
        tooltip: _unavailableReason(l10n, note.readiness),
        icon: Icon(Icons.videocam_off_outlined, color: chatix.danger),
        onPressed: _note.dismissUnavailable,
      );
    }

    if (voice.stage == VoiceRecordStage.locked || voice.holdsRecording) {
      // Hands free, or stopped by the 600-second cap: the gesture is over,
      // so the two things it could still have meant become two buttons that
      // say which is which.
      return _Decision(
        onCancel: () => unawaited(_voice.cancel()),
        onSend: () => unawaited(_finishRecording()),
        sendLabel: l10n.voiceSendRecording,
      );
    }

    if (note.stage == VideoNoteStage.locked || note.holdsRecording) {
      return _Decision(
        onCancel: () => unawaited(_note.cancel()),
        onSend: () => unawaited(_finishNote()),
        sendLabel: l10n.videoNoteSend,
      );
    }

    final isWaiting = secondsLeft > 0;

    // Which recorder the hold drives. A chat that cannot take one of the two
    // leaves the button on the other rather than offering a swap to nothing.
    final canRecordVoice = widget.onVoiceRecorded != null;
    final canRecordNote = widget.onVideoNoteRecorded != null;
    final mode = canRecordNote && canRecordVoice
        ? ref.watch(composerRecordModeProvider)
        : (canRecordNote ? ComposerRecordMode.videoNote
                         : ComposerRecordMode.voice);

    final isVideoNote = mode == ComposerRecordMode.videoNote;
    final isHeld = isVideoNote ? note.isActive : voice.isRecording;

    // Holding to record is only on offer in the microphone shape, but the
    // gesture detector stays in the tree either way: swapping it in and out
    // would rebuild the circle underneath, and a rebuilt circle starts its
    // icons over instead of morphing them.
    final holdToRecord =
        widget.action == ComposerAction.record &&
        (canRecordVoice || canRecordNote) &&
        !isWaiting;

    // A tap on the microphone has nothing to send, so it is free to mean the
    // other thing: swap which recorder the hold will use.
    final canSwapMode = holdToRecord && canRecordVoice && canRecordNote;

    final label = switch (widget.action) {
      ComposerAction.record =>
        isVideoNote ? l10n.composerRecordVideoNoteLabel : l10n.composerRecordLabel,
      ComposerAction.send => l10n.composerSendLabel,
      ComposerAction.save => l10n.composerSaveEditLabel,
    };

    final button = _Circle(
      // A tooltip installs a long-press recogniser of its own, and it sits
      // inside this button's — so on a touch device it would win the arena
      // and swallow every hold. While the hold means "record", the tooltip
      // is left to hover only.
      holdsLongPress: !holdToRecord,
      // The microphone sits on the surface; anything that sends is filled,
      // which is the difference between "you could" and "you can".
      filled: widget.action != ComposerAction.record,
      // The microphone has something to do even with an empty box, so it
      // is not a disabled control — it just does not send.
      enabled: holdToRecord || (widget.enabled && !isWaiting),
      danger: isHeld && (isVideoNote ? note.willCancel : voice.willCancel),
      onTap: switch (widget.action) {
        _ when isWaiting => null,
        ComposerAction.record => canSwapMode
            ? ref.read(composerRecordModeProvider.notifier).toggle
            : null,
        _ => widget.enabled ? widget.onSend : null,
      },
      semanticsLabel: isWaiting ? l10n.composerSlowModeWait(secondsLeft) : label,
      tooltip: switch (widget.action) {
        _ when isWaiting =>
          l10n.composerSlowModeHint(widget.slowMode.interval.inSeconds),
        ComposerAction.record when canSwapMode => isVideoNote
            ? l10n.composerSwitchToVoice
            : l10n.composerSwitchToVideoNote,
        _ => null,
      },
      child: isWaiting
          ? _Countdown(seconds: secondsLeft, style: theme.textTheme.labelLarge)
          : _MorphIcon(
              action: widget.action,
              pressed: isHeld,
              recordIcon: isVideoNote
                  ? Icons.videocam_outlined
                  : Icons.mic_none_rounded,
            ),
    );

    return GestureDetector(
      onLongPressStart: !holdToRecord
          ? null
          : (details) {
              _origin = details.globalPosition;
              // The haptic belongs to the recording actually starting, which
              // the controller knows about and this does not — the
              // microphone may still be refused.
              unawaited(isVideoNote ? _note.start() : _voice.start());
            },
      onLongPressMoveUpdate: !holdToRecord
          ? null
          : (details) =>
                _onDrag(details.globalPosition, isVideoNote: isVideoNote),
      onLongPressEnd: !holdToRecord
          ? null
          : (_) {
              if (isVideoNote) {
                final stage = ref.read(videoNoteRecordProvider).stage;
                if (stage == VideoNoteStage.preparing) {
                  unawaited(_note.cancel());
                  return;
                }
                if (stage != VideoNoteStage.recording) return;
                if (ref.read(videoNoteRecordProvider).willCancel) {
                  unawaited(_note.cancel());
                  return;
                }
                unawaited(_finishNote());
                return;
              }

              final state = ref.read(voiceRecordProvider);
              if (state.stage != VoiceRecordStage.holding) return;
              if (state.willCancel) {
                unawaited(_voice.cancel());
                return;
              }
              unawaited(_finishRecording());
            },
      onLongPressCancel: !holdToRecord
          ? null
          : () {
              if (isVideoNote) {
                final stage = ref.read(videoNoteRecordProvider).stage;
                // Only a take still in the thumb's hands: one the cap has
                // already stopped belongs to the two buttons now.
                if (stage == VideoNoteStage.recording ||
                    stage == VideoNoteStage.preparing) {
                  unawaited(_note.cancel());
                }
                return;
              }

              if (ref.read(voiceRecordProvider).stage !=
                  VoiceRecordStage.holding) {
                return;
              }
              unawaited(_voice.cancel());
            },
      // The sixty seconds, drawn where the thumb already is. Only while a
      // take is open: an empty ring around an idle button is decoration.
      child: note.isActive
          ? SizedBox(
              width: ComposerSendButton.diameter + _ringInset * 2,
              height: ComposerSendButton.diameter + _ringInset * 2,
              child: ProgressRing(
                progress: note.progress,
                color: note.willCancel ? chatix.danger : theme.colorScheme.primary,
                trackColor: theme.colorScheme.outlineVariant,
                child: Center(child: button),
              ),
            )
          : button,
    );
  }

  /// How far outside the button the countdown ring sits.
  static const double _ringInset = 5;

  static String _unavailableReason(
    AppLocalizations l10n,
    VideoNoteReadiness? readiness,
  ) => switch (readiness) {
    VideoNoteReadiness.denied => l10n.videoNoteCameraDenied,
    VideoNoteReadiness.noCamera => l10n.videoNoteNoCamera,
    VideoNoteReadiness.tooLarge => l10n.videoNoteTooLarge(
      ChatAttachmentLimits.maxVideoNoteResolutionPx,
    ),
    _ => l10n.videoNoteCameraFailed,
  };
}

/// A recording nobody is holding any more, and the two things it could still
/// become. Shared by both recorders, which reach this the same two ways:
/// hands free, or stopped by the cap.
class _Decision extends StatelessWidget {
  const _Decision({
    required this.onCancel,
    required this.onSend,
    required this.sendLabel,
  });

  final VoidCallback onCancel;
  final VoidCallback onSend;
  final String sendLabel;

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: chatix.danger,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
            minimumSize: const Size(0, ComposerSendButton.diameter),
            visualDensity: VisualDensity.compact,
          ),
          child: Text(l10n.voiceCancelRecording),
        ),
        const SizedBox(width: AppSpacing.x1),
        _Circle(
          filled: true,
          enabled: true,
          onTap: onSend,
          semanticsLabel: sendLabel,
          child: const _MorphIcon(action: ComposerAction.send),
        ),
      ],
    );
  }
}

/// The button's body: a circle that fills in when it has something to do.
class _Circle extends StatelessWidget {
  const _Circle({
    required this.filled,
    required this.enabled,
    required this.onTap,
    required this.semanticsLabel,
    required this.child,
    this.danger = false,
    this.tooltip,
    this.holdsLongPress = true,
  });

  final bool filled;
  final bool enabled;
  final bool danger;
  final VoidCallback? onTap;
  final String semanticsLabel;

  /// Whether the tooltip may claim a long press. False wherever something
  /// outside this button is listening for one — a tooltip's recogniser is
  /// the inner of the two and would take every hold.
  final bool holdsLongPress;

  /// Shown on hover or long press when it says more than the label does —
  /// why the button is counting down, rather than what it would do.
  final String? tooltip;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);

    final background = danger
        ? chatix.danger
        : (filled
              ? (enabled
                    ? scheme.primary
                    : scheme.primary.withValues(alpha: 0.35))
              : Colors.transparent);

    final foreground = danger || filled
        ? scheme.onPrimary
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltip ?? semanticsLabel,
          triggerMode: holdsLongPress ? null : TooltipTriggerMode.manual,
          child: InkResponse(
            onTap: onTap,
            radius: ComposerSendButton.diameter * 0.6,
            customBorder: const CircleBorder(),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.curve,
              width: ComposerSendButton.diameter,
              height: ComposerSendButton.diameter,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: background,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: foreground, size: 22),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: foreground),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Three icons in one place, with only one of them at full strength.
///
/// Each icon's opacity, scale and rotation come from how far it is from the
/// current action, so changing action moves a continuous value rather than
/// swapping one widget for another: the microphone tips out as the plane
/// tips in, in the same spot, on the same arc.
class _MorphIcon extends StatelessWidget {
  const _MorphIcon({
    required this.action,
    this.pressed = false,
    this.recordIcon = Icons.mic_none_rounded,
  });

  final ComposerAction action;

  /// A held microphone swells slightly, so the recording has a source.
  final bool pressed;

  /// What the [ComposerAction.record] slot draws — a microphone or a camera,
  /// depending on which recorder the hold will use. Swapped in place rather
  /// than by exchanging widgets, so the change reads as the same control
  /// turning over.
  final IconData recordIcon;

  static const List<IconData> _icons = [
    Icons.mic_none_rounded,
    Icons.send_rounded,
    Icons.check_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: action.index.toDouble()),
      duration: AppMotion.base,
      curve: AppMotion.curve,
      builder: (context, position, _) => Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < _icons.length; i++)
            _MorphLayer(
              icon: i == ComposerAction.record.index ? recordIcon : _icons[i],
              // 0 when this icon is the one being shown, 1 a whole step away.
              distance: (position - i).abs().clamp(0.0, 1.0),
              pressed: pressed && i == ComposerAction.record.index,
            ),
        ],
      ),
    );
  }
}

class _MorphLayer extends StatelessWidget {
  const _MorphLayer({
    required this.icon,
    required this.distance,
    required this.pressed,
  });

  final IconData icon;
  final double distance;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    if (distance >= 1) return const SizedBox.shrink();

    final presence = 1 - distance;

    return Opacity(
      opacity: presence,
      child: Transform.rotate(
        // A quarter turn across a full step: enough to read as movement,
        // little enough that a half-way frame still looks like an icon.
        angle: distance * 0.9,
        child: Transform.scale(
          scale: (0.4 + 0.6 * presence) * (pressed ? 1.15 : 1),
          child: Icon(icon),
        ),
      ),
    );
  }
}

/// The seconds left before slow mode lets the next message out.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.seconds, this.style});

  final int seconds;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = seconds >= 60
        ? '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}'
        : '$seconds';

    return AnimatedSwitcher(
      duration: AppMotion.fast,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style?.copyWith(
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
