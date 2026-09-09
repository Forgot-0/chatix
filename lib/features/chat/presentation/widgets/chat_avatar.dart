import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:chatix/core/media/avatar_variants.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';

/// The sizes an avatar is allowed to be.
///
/// A fixed set rather than a free `radius`: avatars line up across screens
/// only if there are a handful of them, and the ring, notch and initial all
/// scale off the diameter.
enum ChatAvatarSize {
  /// Reaction faces, inline mentions.
  xs(28),

  /// List rows, message gutters.
  sm(40),

  /// App bars, member rows.
  md(52),

  /// Profile headers.
  lg(96);

  const ChatAvatarSize(this.diameter);

  final double diameter;

  double get initialFontSize => diameter * 0.4;

  /// The presence dot, and the gap the notch cuts around it.
  double get dotDiameter => math.max(8, diameter * 0.28);

  double get dotGap => math.max(2, diameter * 0.05);
}

/// Where an avatar image comes from.
///
/// The chat endpoints hand out a single presigned URL, profiles hand out the
/// `avatars` matrix (api-docs §4.3), and tests want to supply bytes. All
/// three end up here so the widget itself only ever sees an [ImageProvider].
@immutable
class AvatarSource {
  const AvatarSource._({this.directUrl, this.variants, this.cacheKey, this.provider});

  /// A single URL — what `ChatProfileDTO.avatar_url` gives us.
  ///
  /// [cacheKey] should be the object's `s3_key`: the URL itself is presigned
  /// and its signature changes on every response (300 s TTL), so caching by
  /// it would miss every time and expire under a live widget.
  factory AvatarSource.url(String url, {String? cacheKey}) =>
      AvatarSource._(directUrl: url, cacheKey: cacheKey);

  /// The `ProfileDTO.avatars` matrix: 4 sizes × 3 formats, `{}` when unset.
  factory AvatarSource.variants(
    Map<String, Map<String, String>> avatars, {
    String? cacheKey,
  }) => AvatarSource._(variants: avatars, cacheKey: cacheKey);

  /// An already-built provider — asset or memory bytes, used by goldens.
  factory AvatarSource.provider(ImageProvider provider) =>
      AvatarSource._(provider: provider);

  /// No picture: the widget draws initials.
  static const AvatarSource none = AvatarSource._();

  final String? directUrl;
  final Map<String, Map<String, String>>? variants;
  final String? cacheKey;
  final ImageProvider? provider;

  bool get isEmpty =>
      provider == null &&
      (directUrl == null || directUrl!.isEmpty) &&
      (variants == null || variants!.isEmpty);

  /// Resolves to a provider for something drawn [logicalSize] wide at
  /// [devicePixelRatio], or null when there is nothing to draw.
  ImageProvider? resolve({
    required double logicalSize,
    required double devicePixelRatio,
  }) {
    final ready = provider;
    if (ready != null) return ready;

    final url = _url(
      preferredSize: (logicalSize * devicePixelRatio).ceil(),
    );
    if (url == null || url.isEmpty) return null;

    return CachedNetworkImageProvider(url, cacheKey: cacheKey ?? url);
  }

  String? _url({required int preferredSize}) {
    final matrix = variants;
    if (matrix != null && matrix.isNotEmpty) {
      return pickAvatarUrl(matrix, preferredSize: preferredSize);
    }
    return directUrl;
  }
}

/// A round avatar: the picture when there is one, initials on a per-author
/// colour when there is not, and an optional presence dot that sits in a
/// notch cut out of the circle rather than on top of it.
class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    this.source = AvatarSource.none,
    this.userId,
    this.name,
    this.size = ChatAvatarSize.sm,
    this.isOnline,
    this.onlineLabel,
  });

  /// Builds one from the profile the chat endpoints attach to members and
  /// messages, which carries a presigned URL plus the stable `s3_key`.
  factory ChatAvatar.profile(
    ChatProfileEntity? profile, {
    Key? key,
    int? userId,
    ChatAvatarSize size = ChatAvatarSize.sm,
    bool? isOnline,
    String? onlineLabel,
  }) {
    final url = profile?.avatarUrl;
    return ChatAvatar(
      key: key,
      source: url == null || url.isEmpty
          ? AvatarSource.none
          : AvatarSource.url(url, cacheKey: profile?.avatarS3Key),
      userId: profile?.userId ?? userId,
      name: profile?.bestName,
      size: size,
      isOnline: isOnline,
      onlineLabel: onlineLabel,
    );
  }

  final AvatarSource source;

  /// Decides the fallback colour, so the same person keeps the same circle
  /// everywhere — the palette is the one author names are drawn from.
  final int? userId;

  /// Where the initial comes from. `bestName` on the profile entity.
  final String? name;

  final ChatAvatarSize size;

  /// null and false both mean "do not claim anything about presence".
  final bool? isOnline;

  /// Read out by screen readers when the dot is showing.
  final String? onlineLabel;

  @override
  Widget build(BuildContext context) {
    final showsPresence = isOnline == true;
    final chatix = ChatixTheme.of(context);
    final diameter = size.diameter;

    final circle = SizedBox(
      width: diameter,
      height: diameter,
      child: ClipPath(
        clipper: showsPresence
            ? _PresenceNotchClipper(
                dotDiameter: size.dotDiameter,
                gap: size.dotGap,
              )
            : const _CircleClipper(),
        child: _AvatarFace(
          source: source,
          userId: userId,
          name: name,
          size: size,
        ),
      ),
    );

    if (!showsPresence) return circle;

    return Semantics(
      label: onlineLabel,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          children: [
            Positioned.fill(child: circle),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size.dotDiameter,
                height: size.dotDiameter,
                decoration: BoxDecoration(
                  color: chatix.onlineDot,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Up to four faces in one circle, for a group that has no avatar of its own.
class ChatAvatarMosaic extends StatelessWidget {
  const ChatAvatarMosaic({
    super.key,
    required this.faces,
    this.size = ChatAvatarSize.sm,
    this.fallbackIcon = Icons.groups_outlined,
  });

  /// Members to draw, in roster order. More than four are ignored: past that
  /// the tiles are too small to tell anyone apart.
  final List<AvatarFace> faces;

  final ChatAvatarSize size;

  /// Drawn when the group has no members to show at all.
  final IconData fallbackIcon;

  static const int maxTiles = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final diameter = size.diameter;
    final shown = faces.take(maxTiles).toList();

    if (shown.isEmpty) {
      return SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            fallbackIcon,
            size: diameter * 0.5,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: CustomMultiChildLayout(
          delegate: _MosaicLayout(shown.length),
          children: [
            for (var i = 0; i < shown.length; i++)
              LayoutId(
                id: i,
                child: _AvatarFace(
                  source: shown[i].source,
                  userId: shown[i].userId,
                  name: shown[i].name,
                  size: size,
                  isTile: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One member of a [ChatAvatarMosaic].
@immutable
class AvatarFace {
  const AvatarFace({this.source = AvatarSource.none, this.userId, this.name});

  factory AvatarFace.profile(ChatProfileEntity profile) {
    final url = profile.avatarUrl;
    return AvatarFace(
      source: url == null || url.isEmpty
          ? AvatarSource.none
          : AvatarSource.url(url, cacheKey: profile.avatarS3Key),
      userId: profile.userId,
      name: profile.bestName,
    );
  }

  final AvatarSource source;
  final int? userId;
  final String? name;
}

/// The picture-or-initial itself, without any clipping or presence dot.
class _AvatarFace extends StatelessWidget {
  const _AvatarFace({
    required this.source,
    required this.userId,
    required this.name,
    required this.size,
    this.isTile = false,
  });

  final AvatarSource source;
  final int? userId;
  final String? name;
  final ChatAvatarSize size;

  /// Tiles sit inside a mosaic, so their initial has to shrink.
  final bool isTile;

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);
    final background = chatix.authorColor(userId);
    final foreground = _foregroundOn(background);

    final provider = source.resolve(
      logicalSize: isTile ? size.diameter / 2 : size.diameter,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );

    final initial = Container(
      color: background,
      alignment: Alignment.center,
      child: Text(
        _initialOf(name),
        style: TextStyle(
          color: foreground,
          fontSize: isTile ? size.initialFontSize * 0.6 : size.initialFontSize,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
    );

    if (provider == null) return initial;

    return Stack(
      fit: StackFit.expand,
      children: [
        initial,
        Image(
          image: provider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // A dead link (an expired presigned URL, most often) leaves the
          // initial showing instead of a broken-image glyph.
          errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  static Color _foregroundOn(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : const Color(0xFF14120F);

  static String _initialOf(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return '?';

    final cleaned = trimmed.replaceFirst(RegExp(r'^[@#]+'), '').trim();
    if (cleaned.isEmpty) return '?';
    return cleaned.characters.first.toUpperCase();
  }
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper();

  @override
  Path getClip(Size size) =>
      Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// The circle with a bite taken out of it where the presence dot goes.
///
/// A dot drawn on top of the avatar covers part of the picture and needs its
/// own outline to stay legible against it; a notch means the dot never
/// touches the image at all, and the ring around it is the page behind.
class _PresenceNotchClipper extends CustomClipper<Path> {
  const _PresenceNotchClipper({required this.dotDiameter, required this.gap});

  final double dotDiameter;
  final double gap;

  @override
  Path getClip(Size size) {
    final circle = Path()
      ..addOval(Rect.fromLTWH(0, 0, size.width, size.height));

    final radius = dotDiameter / 2 + gap;
    final centre = Offset(
      size.width - dotDiameter / 2,
      size.height - dotDiameter / 2,
    );

    final hole = Path()..addOval(Rect.fromCircle(center: centre, radius: radius));

    return Path.combine(PathOperation.difference, circle, hole);
  }

  @override
  bool shouldReclip(covariant _PresenceNotchClipper oldClipper) =>
      oldClipper.dotDiameter != dotDiameter || oldClipper.gap != gap;
}

/// 1 face fills the circle, 2 split it vertically, 3 put one on the left and
/// two stacked on the right, 4 make a quadrant grid.
class _MosaicLayout extends MultiChildLayoutDelegate {
  _MosaicLayout(this.count);

  final int count;

  @override
  void performLayout(Size size) {
    final half = Size(size.width / 2, size.height / 2);
    final tall = Size(size.width / 2, size.height);

    switch (count) {
      case 1:
        _place(0, size, Offset.zero);
      case 2:
        _place(0, tall, Offset.zero);
        _place(1, tall, Offset(half.width, 0));
      case 3:
        _place(0, tall, Offset.zero);
        _place(1, half, Offset(half.width, 0));
        _place(2, half, Offset(half.width, half.height));
      default:
        _place(0, half, Offset.zero);
        _place(1, half, Offset(half.width, 0));
        _place(2, half, Offset(0, half.height));
        _place(3, half, Offset(half.width, half.height));
    }
  }

  void _place(int id, Size size, Offset offset) {
    if (!hasChild(id)) return;
    layoutChild(id, BoxConstraints.tight(size));
    positionChild(id, offset);
  }

  @override
  bool shouldRelayout(covariant _MosaicLayout oldDelegate) =>
      oldDelegate.count != count;
}
