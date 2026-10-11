import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The profile's QR code in a sheet, with the two things to do with it:
/// share the link, or copy it.
///
/// What the code holds is [ProfileShareLink] — the app's own route on the
/// host this build talks to. The API has no public page for a profile
/// (see that class), so the code is for another ChatiX, not for a browser,
/// and the sheet says so.
Future<void> showProfileQrSheet(
  BuildContext context, {
  required int profileId,
  required String name,
  required String username,
  required Future<void> Function() onShare,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => ProfileQrSheet(
      profileId: profileId,
      name: name,
      username: username,
      onShare: () async {
        Navigator.of(sheetContext).pop();
        await onShare();
      },
    ),
  );
}

class ProfileQrSheet extends StatelessWidget {
  const ProfileQrSheet({
    super.key,
    required this.profileId,
    required this.name,
    required this.username,
    required this.onShare,
  });

  final int profileId;
  final String name;

  /// Without the `@`.
  final String username;

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final link = ProfileShareLink.of(profileId);

    return SafeArea(
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          // A card's worth of width on a desktop, where the sheet itself
          // runs most of the pane.
          constraints: const BoxConstraints(
            maxWidth: AppDialogSizes.pickerMaxWidth,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x6,
              0,
              AppSpacing.x6,
              AppSpacing.x6,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.x1),
                Text(
                  '@$username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),
                Semantics(
                  image: true,
                  label: l10n.profileActionQr,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppPalette.qrGround,
                      borderRadius: BorderRadius.circular(
                        ProfileLayout.qrTileRadius,
                      ),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(ProfileLayout.qrPadding),
                      child: QrImageView(
                        data: link,
                        size: ProfileLayout.qrSize,
                        padding: EdgeInsets.zero,
                        backgroundColor: AppPalette.qrGround,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: AppPalette.qrInk,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppPalette.qrInk,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                Text(
                  l10n.profileQrHint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.x5),
                // One over the other: "Скопировать ссылку" does not fit half a
                // phone, and the share button is the one most people want.
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share),
                    label: Text(l10n.profileShareAction),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _copy(context, link),
                    icon: const Icon(Icons.link),
                    label: Text(l10n.profileCopyLink),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copy(BuildContext context, String link) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    AppSnackbar.quiet(context, AppLocalizations.of(context).profileShareCopied);
  }
}
