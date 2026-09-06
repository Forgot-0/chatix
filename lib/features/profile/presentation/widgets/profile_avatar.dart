import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

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
