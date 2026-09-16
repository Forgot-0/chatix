import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';

/// The chat's face at the top of its profile, shrinking as the page scrolls.
///
/// A hand-laid header rather than a [FlexibleSpaceBar]: the avatar has to
/// travel from the middle of a tall card to the left of a toolbar while
/// changing size, and the title has to slide out from under it, which is two
/// interpolations the stock widget does not offer.
class ChatProfileHeader extends SliverPersistentHeaderDelegate {
  ChatProfileHeader({
    required this.chat,
    required this.myUserId,
    required this.title,
    required this.subtitle,
    required this.topPadding,
    required this.onBack,
    this.trailing,
  });

  /// How tall the expanded card is, below the status bar.
  static const double expandedHeight = 212;

  /// The collapsed bar is a toolbar, so it is a toolbar's height.
  static const double collapsedHeight = kToolbarHeight;

  static const double _bigAvatar = 96;
  static const double _smallAvatar = 36;

  /// Where the back button ends and the collapsed avatar may start.
  static const double _leadingInset = 52;

  final ChatEntity chat;
  final int? myUserId;

  final String title;

  /// Type, member count, or presence — whatever the line under the name
  /// says for this kind of chat.
  final String subtitle;

  final double topPadding;
  final VoidCallback onBack;

  /// The one action that belongs in the bar itself, when there is one.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final travel = maxExtent - minExtent;
    final t = travel <= 0 ? 1.0 : (shrinkOffset / travel).clamp(0.0, 1.0);

    final avatar = lerpDouble(_bigAvatar, _smallAvatar, t)!;
    final width = MediaQuery.sizeOf(context).width;

    final avatarLeft = lerpDouble(
      (width - _bigAvatar) / 2,
      _leadingInset,
      t,
    )!;
    final avatarTop = lerpDouble(
      topPadding + 20,
      topPadding + (collapsedHeight - _smallAvatar) / 2,
      t,
    )!;

    final textLeft = lerpDouble(16, _leadingInset + _smallAvatar + 12, t)!;
    final textTop = lerpDouble(topPadding + 132, topPadding + 8, t)!;

    return Material(
      // Opaque, because the list scrolls underneath it.
      color: scheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // A wash of the chat's own colour behind the big avatar, gone by
          // the time the bar is a bar.
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
            child: FittedBox(
              // The picture is resolved at the largest size it will be drawn
              // at and scaled down from there, so shrinking it costs no
              // second decode and never looks soft.
              fit: BoxFit.contain,
              child: ChatRowAvatar(
                chat: chat,
                myUserId: myUserId,
                size: ChatAvatarSize.lg,
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
                const SizedBox(height: 2),
                _Line(
                  t: t,
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: lerpDouble(13, 12, t),
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // The hairline only belongs to the collapsed bar.
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
  bool shouldRebuild(covariant ChatProfileHeader oldDelegate) {
    return oldDelegate.chat != chat ||
        oldDelegate.myUserId != myUserId ||
        oldDelegate.title != title ||
        oldDelegate.subtitle != subtitle ||
        oldDelegate.topPadding != topPadding ||
        oldDelegate.trailing != trailing;
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
