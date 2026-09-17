import 'package:flutter/material.dart';

import 'package:chatix/core/permissions/media_permissions.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Explains what the microphone or the camera is for, before the platform
/// asks.
///
/// Shown at the moment the user reaches for the device — joining, or turning
/// video on — so the system dialog lands on top of its own reason. Returns
/// true when the user wants to go ahead.
Future<bool> showCallPermissionRationale(
  BuildContext context,
  MediaDeviceKind device,
) async {
  final l10n = AppLocalizations.of(context);

  final answer = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        device == MediaDeviceKind.microphone ? Icons.mic_none : Icons.videocam,
      ),
      title: Text(
        device == MediaDeviceKind.microphone
            ? l10n.callMicrophonePermissionTitle
            : l10n.callCameraPermissionTitle,
      ),
      content: Text(
        device == MediaDeviceKind.microphone
            ? l10n.callMicrophonePermissionBody
            : l10n.callCameraPermissionBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.callPermissionNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.callPermissionContinue),
        ),
      ],
    ),
  );

  return answer ?? false;
}

/// The standing "we were told no" bar.
///
/// A refusal is not a one-off error: the microphone stays off for the rest of
/// the call, so the reason stays on screen. When the platform will not prompt
/// again the only way out is the settings app, and that is the action offered.
class CallPermissionBanner extends StatelessWidget {
  const CallPermissionBanner({
    super.key,
    required this.issue,
    required this.onOpenSettings,
    required this.onDismiss,
  });

  final CallPermissionIssue issue;
  final VoidCallback onOpenSettings;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Icon(
              issue.device == MediaDeviceKind.microphone
                  ? Icons.mic_off
                  : Icons.videocam_off,
              size: 18,
              color: scheme.onErrorContainer,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                issue.device == MediaDeviceKind.microphone
                    ? l10n.callMicrophoneBlocked
                    : l10n.callCameraBlocked,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
              ),
            ),
            if (issue.isPermanent)
              TextButton(
                onPressed: onOpenSettings,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                ),
                child: Text(l10n.callPermissionOpenSettings),
              )
            else
              IconButton(
                tooltip: l10n.callDismiss,
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onErrorContainer,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
