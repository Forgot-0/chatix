import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/data/datasources/voice_recorder.dart';
import 'package:chatix/features/chat/domain/entities/slow_mode.dart';
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
class ComposerSendButton extends ConsumerStatefulWidget {
  const ComposerSendButton({
    super.key,
    required this.action,
    required this.enabled,
    required this.slowMode,
    this.onSend,
    this.onVoiceRecorded,
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

  Future<void> _finishRecording() async {
    final recording = await _voice.stop();
    if (recording != null) widget.onVoiceRecorded?.call(recording);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final voice = ref.watch(voiceRecordProvider);
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

    if (voice.stage == VoiceRecordStage.locked) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l10n.cancel,
            icon: Icon(Icons.delete_outline, color: chatix.danger),
            onPressed: _voice.cancel,
          ),
          _Circle(
            filled: true,
            enabled: true,
            onTap: _finishRecording,
            semanticsLabel: l10n.composerSendLabel,
            child: const _MorphIcon(action: ComposerAction.send),
          ),
        ],
      );
    }

    final isHeld = voice.isRecording;
    final isWaiting = secondsLeft > 0;

    final label = switch (widget.action) {
      ComposerAction.record => l10n.composerRecordLabel,
      ComposerAction.send => l10n.composerSendLabel,
      ComposerAction.save => l10n.composerSaveEditLabel,
    };

    // Holding to record is only on offer in the microphone shape, but the
    // gesture detector stays in the tree either way: swapping it in and out
    // would rebuild the circle underneath, and a rebuilt circle starts its
    // icons over instead of morphing them.
    final holdToRecord =
        widget.action == ComposerAction.record &&
        widget.onVoiceRecorded != null &&
        !isWaiting;

    return GestureDetector(
      onLongPressStart: !holdToRecord
          ? null
          : (details) {
              _origin = details.globalPosition;
              HapticFeedback.mediumImpact();
              unawaited(_voice.start());
            },
      onLongPressMoveUpdate: !holdToRecord
          ? null
          : (details) {
              final delta = details.globalPosition - _origin;

              if (-delta.dy > _lockAt) {
                _voice.lock();
                return;
              }
              _voice.updateDrag(willCancel: -delta.dx > _cancelAt);
            },
      onLongPressEnd: !holdToRecord
          ? null
          : (_) {
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
          : () => unawaited(_voice.cancel()),
      child: _Circle(
        // The microphone sits on the surface; anything that sends is filled,
        // which is the difference between "you could" and "you can".
        filled: widget.action != ComposerAction.record,
        // The microphone has something to do even with an empty box, so it
        // is not a disabled control — it just does not send.
        enabled: holdToRecord || (widget.enabled && !isWaiting),
        danger: isHeld && voice.willCancel,
        onTap: widget.action == ComposerAction.record || isWaiting
            ? null
            : (widget.enabled ? widget.onSend : null),
        semanticsLabel: isWaiting
            ? l10n.composerSlowModeWait(secondsLeft)
            : label,
        tooltip: isWaiting
            ? l10n.composerSlowModeHint(widget.slowMode.interval.inSeconds)
            : null,
        child: isWaiting
            ? _Countdown(
                seconds: secondsLeft,
                style: theme.textTheme.labelLarge,
              )
            : _MorphIcon(action: widget.action, pressed: isHeld),
      ),
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
  });

  final bool filled;
  final bool enabled;
  final bool danger;
  final VoidCallback? onTap;
  final String semanticsLabel;

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
  const _MorphIcon({required this.action, this.pressed = false});

  final ComposerAction action;

  /// A held microphone swells slightly, so the recording has a source.
  final bool pressed;

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
              icon: _icons[i],
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
