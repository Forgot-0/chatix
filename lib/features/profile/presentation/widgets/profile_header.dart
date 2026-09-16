import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';

/// The tag that ties the header's avatar to the full-screen one.
String profileAvatarHeroTag(int profileId) => 'profile-avatar-$profileId';

/// A person's face at the top of their profile, shrinking as the page
/// scrolls.
///
/// Hand-laid rather than a [FlexibleSpaceBar], and deliberately the same
/// shape as the chat profile's header: the avatar travels from the middle of
/// a tall card to the left of a toolbar while changing size, and the name
/// slides out from under it. That is two interpolations the stock widget
/// does not offer, and matching the chat side is what makes the two screens
/// feel like one app.
class ProfileHeader extends SliverPersistentHeaderDelegate {
  ProfileHeader({
    required this.profile,
    required this.title,
    required this.subtitle,
    required this.topPadding,
    required this.onBack,
    required this.onAvatarTap,
    this.avatarAction,
    this.trailing,
  });

  /// How tall the expanded card is, below the status bar.
  static const double expandedHeight = 236;

  static const double collapsedHeight = kToolbarHeight;

  static const double _bigAvatar = 112;
  static const double _smallAvatar = 36;

  /// Where the back button ends and the collapsed avatar may start.
  static const double _leadingInset = 52;

  final ProfileEntity profile;

  /// The display name, or the best stand-in when there is none.
  final String title;

  /// `@username` when it is known, the specialization otherwise — whichever
  /// identifies the person on one line.
  final String subtitle;

  final double topPadding;
  final VoidCallback onBack;

  /// Opens the picture full screen. Null when there is no picture to open.
  final VoidCallback? onAvatarTap;

  /// Sits on the corner of the expanded avatar — the "change photo" button
  /// on one's own profile, nothing on anyone else's. Fades out with the
  /// card, because there is no room for it on a toolbar.
  final Widget? avatarAction;

  final Widget? trailing;

  @override
  double get maxExtent => topPadding + expandedHeight;

  @override
  double get minExtent => topPadding + collapsedHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;

    final travel = maxExtent - minExtent;
    final t = travel <= 0 ? 1.0 : (shrinkOffset / travel).clamp(0.0, 1.0);

    final avatar = lerpDouble(_bigAvatar, _smallAvatar, t)!;
    final width = MediaQuery.sizeOf(context).width;

    final avatarLeft = lerpDouble((width - _bigAvatar) / 2, _leadingInset, t)!;
    final avatarTop = lerpDouble(
      topPadding + 24,
      topPadding + (collapsedHeight - _smallAvatar) / 2,
      t,
    )!;

    final textLeft = lerpDouble(16, _leadingInset + _smallAvatar + 12, t)!;
    final textTop = lerpDouble(topPadding + 152, topPadding + 8, t)!;

    return Material(
      // Opaque, because the page scrolls underneath it.
      color: scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 1 - t,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        scheme.primaryContainer.withValues(alpha: 0.45),
                        scheme.surface,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          Positioned(
            left: 4,
            top: topPadding + (collapsedHeight - 48) / 2,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack,
            ),
          ),

          if (trailing != null)
            Positioned(
              right: 4,
              top: topPadding + (collapsedHeight - 48) / 2,
              child: trailing!,
            ),

          Positioned(
            left: avatarLeft,
            top: avatarTop,
            width: avatar,
            height: avatar,
            child: GestureDetector(
              onTap: onAvatarTap,
              child: FittedBox(
                // Resolved once at the largest size it will be drawn at and
                // scaled down from there: shrinking costs no second decode
                // and never looks soft.
                fit: BoxFit.contain,
                child: Hero(
                  tag: profileAvatarHeroTag(profile.id),
                  child: ProfileAvatar(
                    profile: profile,
                    radius: _bigAvatar / 2,
                  ),
                ),
              ),
            ),
          ),

          if (avatarAction != null && t < 1)
            Positioned(
              left: avatarLeft + avatar - 18,
              top: avatarTop + avatar - 18,
              child: Opacity(
                opacity: (1 - t * 2).clamp(0.0, 1.0),
                child: IgnorePointer(
                  ignoring: t > 0.4,
                  child: avatarAction,
                ),
              ),
            ),

          Positioned(
            left: textLeft,
            right: lerpDouble(16, trailing == null ? 16 : _leadingInset, t)!,
            top: textTop,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Line(
                  t: t,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: lerpDouble(22, 17, t),
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _Line(
                    t: t,
                    child: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: lerpDouble(14, 12, t),
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Opacity(
              opacity: t,
              child: Divider(height: 1, color: scheme.outlineVariant),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ProfileHeader oldDelegate) {
    return oldDelegate.profile != profile ||
        oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.trailing != trailing ||
        oldDelegate.avatarAction != avatarAction ||
        (oldDelegate.onAvatarTap == null) != (onAvatarTap == null);
  }
}

/// One line of the header, gliding from centred to left-aligned.
///
/// [Align] rather than a change of `crossAxisAlignment`, which cannot be
/// interpolated: the alignment itself is lerped, so the text drifts across
/// instead of jumping when the bar collapses.
class _Line extends StatelessWidget {
  const _Line({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.lerp(Alignment.center, Alignment.centerLeft, t)!,
      child: child,
    );
  }
}
