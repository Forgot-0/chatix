import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chatix/core/error/failure_messages.dart';

/// Own-profile-only avatar widget: shows the current avatar, a camera
/// button to replace it, and a step indicator over the 3-step upload flow
/// (api-docs §4.5) — presigning → uploading → confirming → done.
class AvatarPickerWidget extends ConsumerWidget {
  final ProfileEntity profile;

  const AvatarPickerWidget({super.key, required this.profile});

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    } catch (_) {
      if (context.mounted) {
        AppUtils.showSnackBar(context, message: 'Could not open the photo library');
      }
      return;
    }
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    if (!context.mounted) return;
    await ref
        .read(avatarUploadProvider.notifier)
        .upload(
          profileId: profile.id,
          bytes: bytes,
          filename: picked.name,
          contentType: picked.mimeType ?? _contentTypeFromFilename(picked.name),
        );
  }

  String _contentTypeFromFilename(String filename) {
    final extension = filename.split('.').last.toLowerCase();
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  String _stageLabel(AvatarUploadStage stage) {
    switch (stage) {
      case AvatarUploadStage.presigning:
        return 'Preparing upload…';
      case AvatarUploadStage.uploading:
        return 'Uploading…';
      case AvatarUploadStage.confirming:
        return 'Confirming…';
      case AvatarUploadStage.done:
        return 'Avatar updated';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uploadState = ref.watch(avatarUploadProvider);

    ref.listen(avatarUploadProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        final error = next.error;
        AppUtils.showSnackBar(
          context,
          message: friendlyFailureMessage(error, fallback: 'Could not update avatar'),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    });

    final isBusy = uploadState.isLoading;
    final stage = uploadState.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Opacity(opacity: isBusy ? 0.5 : 1, child: ProfileAvatar(profile: profile, radius: 48)),
            if (isBusy) const CircularProgressIndicator(),
            Positioned(
              bottom: 0,
              right: 0,
              child: IconButton.filled(
                iconSize: 18,
                onPressed: isBusy ? null : () => _pickAndUpload(context, ref),
                icon: const Icon(Icons.camera_alt),
              ),
            ),
          ],
        ),
        if (stage != null) ...[
          const SizedBox(height: 8),
          Text(_stageLabel(stage), style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
