import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/domain/entities/avatar_upload_stage.dart';
import 'package:chatix/features/profile/presentation/providers/avatar_upload_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_picker_widget.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The reader at the top of settings: their face, their name and handle,
/// and the two things people come here to change — the photo (the camera on
/// the face) and everything else ("Edit"). The rest of the card opens the
/// profile itself.
///
/// Drawn from the signed-in account until the profile arrives, so the card
/// never stands empty: the handle is known from sign-in, the name and the
/// photo only from `GET /profiles/my/` (api-docs §4.1).
class SettingsProfileCard extends ConsumerWidget {
  const SettingsProfileCard({
    super.key,
    required this.onOpen,
    required this.onEdit,
    this.selected = false,
  });

  final VoidCallback onOpen;
  final VoidCallback onEdit;

  /// The profile is open beside the list in a two-pane window.
  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final me = ref.watch(authProvider).value;
    if (me == null) return const SizedBox.shrink();

    final profile = ref.watch(profileDetailProvider(me.id)).value;
    final username = profile?.username ?? me.username;
    final name = profile?.displayName?.trim();
    final hasName = name != null && name.isNotEmpty;

    final avatar = profile == null
        ? ChatAvatar(userId: me.id, name: username, size: ChatAvatarSize.card)
        : ChatAvatar.person(profile, size: ChatAvatarSize.card);

    return AppGroupedSection(
      children: [
        Material(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x3,
                AppSpacing.x2,
                AppSpacing.x3,
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: ChatAvatarSize.card.diameter,
                    child: Stack(
                      children: [
                        avatar,
                        if (profile != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: _CameraBadge(profileId: profile.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SettingsLayout.cardAvatarGap),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: selected,
                      hint: l10n.settingsProfileOpen,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasName ? name : '@$username',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: SettingsLayout.lineGap),
                          Text(
                            hasName ? '@$username' : me.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onEdit,
                    child: Text(l10n.profileEditAction),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (profile != null && _uploadInFlight(ref.watch(avatarUploadProvider)))
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x2,
            ),
            child: AvatarUploadStatus(),
          ),
      ],
    );
  }
}

/// The camera on the corner of the face: picks, crops and uploads a new
/// photo without leaving settings — the same flow the profile's own camera
/// starts.
class _CameraBadge extends StatelessWidget {
  const _CameraBadge({required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AvatarPicker(
      profileId: profileId,
      builder: (context, pick, busy) => IconButton.filled(
        tooltip: l10n.changePhoto,
        iconSize: SettingsLayout.cameraIcon,
        onPressed: pick,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(SettingsLayout.cameraBadge),
          minimumSize: const Size.square(SettingsLayout.cameraBadge),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          // A busy badge keeps its colour: the spinner is the news, not
          // a greyed-out button.
          disabledBackgroundColor: scheme.primary,
          side: BorderSide(
            color: AppGroupedSection.surfaceOf(theme),
            width: SettingsLayout.cameraRing,
          ),
        ),
        icon: busy
            ? SizedBox.square(
                dimension: SettingsLayout.cameraIcon,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.onPrimary,
                ),
              )
            : const Icon(Icons.photo_camera_rounded),
      ),
    );
  }
}

/// Whether a new photo is on its way, or did not take — the only times
/// the card says anything under itself. Once it is done there is nothing to
/// say: a card that kept repeating "Photo updated" would be a card with a
/// stale sentence on it. The moment before the first stage is the camera's
/// spinner to show, not a line of its own.
bool _uploadInFlight(AsyncValue<AvatarUploadStage?> upload) {
  if (upload.hasError && !upload.isLoading) return true;
  final stage = upload.value;
  return stage != null && stage != AvatarUploadStage.done;
}
