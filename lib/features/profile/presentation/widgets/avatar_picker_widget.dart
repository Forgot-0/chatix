import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:chatix/features/profile/presentation/utils/avatar_image.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_cropper.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The "change photo" button, and everything that happens after it is
/// tapped.
///
/// Most of the work is deliberately on this side of the wire. The server
/// accepts any bytes, checks them in a background task, and tells nobody
/// what it decided — a file it rejects simply never becomes an avatar
/// (api-docs §4.5). So the picture is decoded, cropped to a square and
/// re-encoded here, which both keeps it inside the 5 MB cap and guarantees
/// it really is an image before a byte is uploaded.
class AvatarPickerButton extends ConsumerStatefulWidget {
  const AvatarPickerButton({super.key, required this.profileId});

  final int profileId;

  @override
  ConsumerState<AvatarPickerButton> createState() => _AvatarPickerButtonState();
}

class _AvatarPickerButtonState extends ConsumerState<AvatarPickerButton> {
  /// True while the picture is being picked, decoded and cropped — before
  /// the upload provider knows anything about it.
  bool _isPreparing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final upload = ref.watch(avatarUploadProvider);
    final busy = _isPreparing || upload.isLoading;

    return IconButton.filled(
      tooltip: l10n.changePhoto,
      iconSize: 18,
      onPressed: busy ? null : _pick,
      icon: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.camera_alt),
    );
  }

  Future<void> _pick() async {
    final source = await _askForSource();
    if (source == null || !mounted) return;

    setState(() => _isPreparing = true);
    try {
      await _prepareAndUpload(source);
    } finally {
      if (mounted) setState(() => _isPreparing = false);
    }
  }

  Future<ImageSource?> _askForSource() {
    final l10n = AppLocalizations.of(context);

    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.choosePhoto),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.camera),
              onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _prepareAndUpload(ImageSource source) async {
    final l10n = AppLocalizations.of(context);

    final XFile? picked;
    try {
      picked = await ImagePicker().pickImage(source: source, imageQuality: 95);
    } catch (_) {
      if (mounted) AppSnackbar.quiet(context, l10n.photoLibraryFailed);
      return;
    }
    if (picked == null) return;

    final Uint8List raw = await picked.readAsBytes();
    if (!mounted) return;

    ui.Image? decoded;
    try {
      decoded = await AvatarImage.decode(raw);
      if (!mounted) return;

      final crop = await showAvatarCropper(context, image: decoded);
      if (crop == null || !mounted) return;

      final prepared = await AvatarImage.render(
        source: decoded,
        crop: crop,
        sourceFilename: picked.name,
      );
      if (!mounted) return;

      await ref
          .read(avatarUploadProvider.notifier)
          .upload(
            profileId: widget.profileId,
            bytes: prepared.bytes,
            filename: prepared.filename,
            contentType: prepared.contentType,
          );
    } on AvatarPreparationException catch (error) {
      if (mounted) {
        AppSnackbar.quiet(context, _preparationMessage(l10n, error.reason));
      }
    } finally {
      decoded?.dispose();
    }
  }

  String _preparationMessage(
    AppLocalizations l10n,
    AvatarPreparationFailure reason,
  ) {
    return switch (reason) {
      AvatarPreparationFailure.undecodable => l10n.avatarUnreadable,
      AvatarPreparationFailure.tooLarge => l10n.avatarTooLarge,
    };
  }
}

/// The line under the avatar while an upload is in flight, and the way back
/// when one did not take.
class AvatarUploadStatus extends ConsumerWidget {
  const AvatarUploadStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final upload = ref.watch(avatarUploadProvider);

    final error = upload.error;
    if (error != null && !upload.isLoading) {
      final canRetry =
          ref.read(avatarUploadProvider.notifier).lastAttempt != null;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error is AvatarProcessingFailure
                ? l10n.avatarProcessingFailed
                : friendlyFailureMessage(
                    error,
                    fallback: l10n.avatarUpdateFailed,
                  ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          if (error is AvatarProcessingFailure)
            Text(
              l10n.avatarProcessingFailedHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (canRetry)
            TextButton.icon(
              onPressed: () =>
                  ref.read(avatarUploadProvider.notifier).retry(),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(l10n.retry),
            ),
        ],
      );
    }

    final stage = upload.value;
    if (stage == null) return const SizedBox.shrink();

    return Text(
      _stageLabel(l10n, stage),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _stageLabel(AppLocalizations l10n, AvatarUploadStage stage) {
    return switch (stage) {
      AvatarUploadStage.presigning => l10n.avatarStagePreparing,
      AvatarUploadStage.uploading => l10n.avatarStageUploading,
      AvatarUploadStage.confirming => l10n.avatarStageConfirming,
      // Not a request of ours: this is the wait for the background task that
      // decides whether the picture was acceptable (api-docs §4.5).
      AvatarUploadStage.processing => l10n.avatarStageProcessing,
      AvatarUploadStage.done => l10n.avatarStageDone,
    };
  }
}
