import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

/// Circular avatar for a [profile], sized to [radius]. Requests the size
/// closest to `radius * 2` physical-ish pixels via
/// `ProfileEntity.bestAvatarUrl` (a *display* diameter, not exact device
/// pixels — the helper already snaps to whichever of 32/64/256/512 the
/// backend actually generated) and falls back to the person's initials
/// when there's no avatar yet or no [displayNameFallback] is given, an
/// icon.
class ProfileAvatar extends StatelessWidget {
  final ProfileEntity profile;
  final double radius;
  final String? displayNameFallback;

  const ProfileAvatar({super.key, required this.profile, this.radius = 24, this.displayNameFallback});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preferredSize = (radius * 2).round();
    final url = profile.bestAvatarUrl(preferredSize);

    if (url == null) {
      final name = displayNameFallback ?? profile.displayName;
      return CircleAvatar(
        radius: radius,
        backgroundColor: theme.colorScheme.primaryContainer,
        child: name != null && name.trim().isNotEmpty
            ? Text(
                name.trim()[0].toUpperCase(),
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.w600,
                ),
              )
            : Icon(Icons.person, color: theme.colorScheme.onPrimaryContainer, size: radius),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: theme.colorScheme.primaryContainer,
      backgroundImage: CachedNetworkImageProvider(url),
    );
  }
}
