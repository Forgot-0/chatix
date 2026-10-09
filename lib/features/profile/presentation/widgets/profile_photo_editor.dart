import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_picker_widget.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The top of the edit screen, the way Telegram lays it out: one's own face,
/// big and centred, and under it the words that change it.
///
/// The face is as much the control as the link under it — tapping either
/// starts the same pick, crop and upload — and while a picture is on its way
/// the face dims under a spinner, so the progress is shown where the new
/// picture will appear rather than somewhere else on the page.
class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({super.key, required this.profile});

  final ProfileEntity profile;

  /// The same size the profile's own header opens at, so the face does not
  /// jump when the editor is pushed over it.
  static const ChatAvatarSize size = ChatAvatarSize.xxl;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = profile.hasAvatar ? l10n.changePhoto : l10n.setPhoto;

    return AvatarPicker(
      profileId: profile.id,
      builder: (context, pick, busy) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The link below is the one control a screen reader is given;
          // the face would only announce the same action a second time.
          ExcludeSemantics(
            child: SizedBox.square(
              dimension: size.diameter,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: profileAvatarHeroTag(profile.id),
                    flightShuttleBuilder: AppHeroFlight.circle,
                    child: ChatAvatar.person(profile, size: size),
                  ),
                  // A ring along the face's own edge rather than a spinner
                  // in its middle, which would sit on top of the initial.
                  if (busy)
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppPalette.mediaScrim,
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.x1),
                        child: CircularProgressIndicator(
                          color: AppPalette.onMediaScrim,
                        ),
                      ),
                    ),
                  // Above the face rather than under it: ink is painted on
                  // the material behind a widget, and the face is opaque.
                  Material(
                    type: MaterialType.transparency,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(onTap: pick),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          TextButton(onPressed: pick, child: Text(label)),
          const AvatarUploadStatus(),
        ],
      ),
    );
  }
}
