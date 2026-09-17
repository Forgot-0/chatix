import 'package:flutter/material.dart';

import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Microphone, camera, speaker, layout, hang up.
///
/// Wrapped rather than spread across a fixed row: with five controls and a
/// large text scale the labels no longer fit one line on a narrow phone, and
/// a wrap keeps every button the same size instead of squeezing them.
class CallControlsBar extends StatelessWidget {
  const CallControlsBar({
    super.key,
    required this.isMicrophoneEnabled,
    required this.isCameraEnabled,
    required this.isSpeakerphoneEnabled,
    required this.canSwitchSpeaker,
    required this.layout,
    required this.onToggleMicrophone,
    required this.onToggleCamera,
    required this.onToggleSpeakerphone,
    required this.onToggleLayout,
    required this.onHangUp,
  });

  final bool isMicrophoneEnabled;
  final bool isCameraEnabled;
  final bool isSpeakerphoneEnabled;
  final bool canSwitchSpeaker;
  final CallLayoutMode layout;

  final VoidCallback onToggleMicrophone;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeakerphone;
  final VoidCallback onToggleLayout;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          CallControlButton(
            icon: isMicrophoneEnabled ? Icons.mic : Icons.mic_off,
            label: isMicrophoneEnabled
                ? l10n.callMicrophoneMute
                : l10n.callMicrophoneUnmute,
            isActive: !isMicrophoneEnabled,
            onPressed: onToggleMicrophone,
          ),
          CallControlButton(
            icon: isCameraEnabled ? Icons.videocam : Icons.videocam_off,
            label: isCameraEnabled ? l10n.callCameraStop : l10n.callCameraStart,
            isActive: isCameraEnabled,
            onPressed: onToggleCamera,
          ),
          if (canSwitchSpeaker)
            CallControlButton(
              icon: isSpeakerphoneEnabled
                  ? Icons.volume_up
                  : Icons.hearing_outlined,
              label: isSpeakerphoneEnabled
                  ? l10n.callSpeakerOn
                  : l10n.callSpeakerOff,
              isActive: isSpeakerphoneEnabled,
              onPressed: onToggleSpeakerphone,
            ),
          CallControlButton(
            icon: layout == CallLayoutMode.grid
                ? Icons.grid_view_outlined
                : Icons.view_sidebar_outlined,
            label: layout == CallLayoutMode.grid
                ? l10n.callLayoutGrid
                : l10n.callLayoutSpeaker,
            onPressed: onToggleLayout,
          ),
          CallControlButton(
            icon: Icons.call_end,
            label: l10n.callLeave,
            background: scheme.error,
            foreground: scheme.onError,
            onPressed: onHangUp,
          ),
        ],
      ),
    );
  }
}

/// One round control with its label underneath.
class CallControlButton extends StatelessWidget {
  const CallControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isActive = false,
    this.background,
    this.foreground,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  /// Filled with the accent — the control is doing something right now
  /// (muted, camera on, speaker on) rather than sitting idle.
  final bool isActive;

  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filled(
            onPressed: onPressed,
            icon: Icon(icon),
            tooltip: label,
            style: IconButton.styleFrom(
              backgroundColor:
                  background ??
                  (isActive ? scheme.primary : scheme.surfaceContainerHighest),
              foregroundColor:
                  foreground ??
                  (isActive ? scheme.onPrimary : scheme.onSurface),
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
