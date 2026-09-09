import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    required this.profile,
    this.userId,
    this.radius = 20,
    this.isOnline,
  });

  final ChatProfileEntity? profile;

  final int? userId;

  final double radius;

  final bool? isOnline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final url = profile?.avatarUrl;
    final key = profile?.avatarS3Key;

    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundImage: (url == null || url.isEmpty)
          ? null
          : CachedNetworkImageProvider(url, cacheKey: key ?? url),
      child: Text(
        _initial,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    if (isOnline != true) return avatar;

    return Stack(
      children: [
        avatar,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.45,
            height: radius * 0.45,
            decoration: BoxDecoration(
              color: scheme.tertiary,
              shape: BoxShape.circle,
              border: Border.all(color: scheme.surface, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  String get _initial {
    final name = profile?.bestName.trim();
    if (name == null || name.isEmpty) return '?';

    final cleaned = name.replaceFirst(RegExp(r'^[@#]+'), '').trim();
    if (cleaned.isEmpty) return '?';
    return cleaned.characters.first.toUpperCase();
  }
}
