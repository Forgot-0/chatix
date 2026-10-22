import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/profile/presentation/utils/avatar_image.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_cropper.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Where a chat's picture comes from, or that it should go.
enum ChatPhotoAction { gallery, camera, remove }

/// Picks a picture from [source], has it cropped to a square and re-encoded
/// — the profile photo's own cropper and encoder — and hands it back, or
/// null when the reader backed out on the way.
typedef ChatPhotoPicker =
    Future<NewChatPhoto?> Function(BuildContext context, ImageSource source);

/// The picker the app uses; a test swaps in one that needs no gallery.
final chatPhotoPickerProvider = Provider<ChatPhotoPicker>(
  (ref) => pickAndCropChatPhoto,
);

/// The real [ChatPhotoPicker].
///
/// Same work as a profile photo, for the same reason: the server checks a
/// chat picture in the background and says nothing when it refuses one
/// (api-docs §5.10), so the picture is decoded, cropped and re-encoded here,
/// which both proves it is an image and keeps it under 5 MB.
Future<NewChatPhoto?> pickAndCropChatPhoto(
  BuildContext context,
  ImageSource source,
) async {
  final l10n = AppLocalizations.of(context);

  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: source, imageQuality: 95);
  } catch (_) {
    if (context.mounted) AppSnackbar.failure(context, l10n.photoLibraryFailed);
    return null;
  }
  if (picked == null || !context.mounted) return null;

  final raw = await picked.readAsBytes();
  if (!context.mounted) return null;

  ui.Image? decoded;
  try {
    decoded = await AvatarImage.decode(raw);
    if (!context.mounted) return null;

    final crop = await showAvatarCropper(context, image: decoded);
    if (crop == null || !context.mounted) return null;

    final prepared = await AvatarImage.render(
      source: decoded,
      crop: crop,
      sourceFilename: picked.name,
    );
    return NewChatPhoto(bytes: prepared.bytes, mimeType: prepared.contentType);
  } on AvatarPreparationException catch (error) {
    if (context.mounted) {
      AppSnackbar.failure(context, switch (error.reason) {
        AvatarPreparationFailure.undecodable => l10n.avatarUnreadable,
        AvatarPreparationFailure.tooLarge => l10n.avatarTooLarge,
      });
    }
    return null;
  } finally {
    decoded?.dispose();
  }
}

/// "Choose a photo", "Camera" — the camera only where there is one to
/// open — and "Remove photo" when there is a photo to remove.
Future<ChatPhotoAction?> showChatPhotoSheet(
  BuildContext context, {
  required bool canRemove,
}) {
  final l10n = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;

  return showModalBottomSheet<ChatPhotoAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.choosePhoto),
            onTap: () =>
                Navigator.of(sheetContext).pop(ChatPhotoAction.gallery),
          ),
          if (!DesktopInput.isDesktop)
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.camera),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatPhotoAction.camera),
            ),
          if (canRemove)
            ListTile(
              leading: Icon(Icons.delete_outline, color: scheme.error),
              title: Text(
                l10n.chatPhotoRemove,
                style: TextStyle(color: scheme.error),
              ),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ChatPhotoAction.remove),
            ),
        ],
      ),
    ),
  );
}

/// The round photo slot beside a new chat's name: a camera on the accent
/// tint while it is empty, the picture once there is one, with a pencil to
/// say it can still be changed.
class NewChatPhotoButton extends ConsumerWidget {
  const NewChatPhotoButton({
    super.key,
    required this.photo,
    required this.onChanged,
    this.enabled = true,
  });

  final NewChatPhoto? photo;
  final ValueChanged<NewChatPhoto?> onChanged;
  final bool enabled;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final action = await showChatPhotoSheet(context, canRemove: photo != null);
    if (action == null || !context.mounted) return;

    if (action == ChatPhotoAction.remove) {
      onChanged(null);
      return;
    }

    final picked = await ref.read(chatPhotoPickerProvider)(
      context,
      action == ChatPhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = photo;

    // A node of its own: next to the name field it would otherwise be read
    // as part of it.
    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: current == null ? l10n.chatPhotoAdd : l10n.changePhoto,
      onTap: enabled ? () => _change(context, ref) : null,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: NewChatLayout.photoSize,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: scheme.primaryContainer,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? () => _change(context, ref) : null,
                child: SizedBox.expand(
                  child: current == null
                      ? Icon(
                          Icons.add_a_photo_outlined,
                          size: NewChatLayout.photoIcon,
                          color: scheme.onPrimaryContainer,
                        )
                      : Ink.image(
                          image: MemoryImage(current.bytes),
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            ),
            if (current != null)
              PositionedDirectional(
                end: -2,
                bottom: -2,
                child: Container(
                  width: NewChatLayout.photoBadge,
                  height: NewChatLayout.photoBadge,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: NewChatLayout.checkBorder,
                    ),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    size: NewChatLayout.photoBadgeIcon,
                    color: scheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
