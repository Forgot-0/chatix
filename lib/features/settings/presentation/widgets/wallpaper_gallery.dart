import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/theme/theme_config.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The name of a wallpaper style, in the reader's language.
String wallpaperLabel(AppLocalizations l10n, AppWallpaper wallpaper) =>
    switch (wallpaper) {
      AppWallpaper.plain => l10n.wallpaperPlain,
      AppWallpaper.mesh => l10n.wallpaperMesh,
      AppWallpaper.aurora => l10n.wallpaperAurora,
      AppWallpaper.nebula => l10n.wallpaperNebula,
      AppWallpaper.ribbons => l10n.wallpaperRibbons,
      AppWallpaper.prism => l10n.wallpaperPrism,
      AppWallpaper.halo => l10n.wallpaperHalo,
      AppWallpaper.dunes => l10n.wallpaperDunes,
    };

/// The wallpaper gallery.
///
/// Every tile is the real painter run at thumbnail size with the reader's own
/// accent, intensity and pattern — so the row re-tints as a whole when the
/// accent changes, and each tile keeps showing what that style would actually
/// look like under the current knobs rather than a fixed sample.
class WallpaperGallery extends StatelessWidget {
  const WallpaperGallery({
    super.key,
    required this.spec,
    required this.selected,
    required this.onSelected,
  });

  /// The current recipe. Only [MeshWallpaperSpec.style] is replaced per tile.
  final MeshWallpaperSpec spec;

  final AppWallpaper selected;
  final ValueChanged<AppWallpaper> onSelected;

  static const double tileWidth = 88;
  static const double tileHeight = 104;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: tileHeight + 30,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        itemCount: AppWallpaper.gallery.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x3),
        itemBuilder: (context, index) {
          final style = AppWallpaper.gallery[index];
          return _WallpaperTile(
            spec: spec.copyWith(style: style),
            label: wallpaperLabel(l10n, style),
            isSelected: style == selected,
            onTap: () => onSelected(style),
          );
        },
      ),
    );
  }
}

class _WallpaperTile extends StatelessWidget {
  const _WallpaperTile({
    required this.spec,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final MeshWallpaperSpec spec;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);

    return Semantics(
      selected: isSelected,
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: WallpaperGallery.tileWidth,
              height: WallpaperGallery.tileHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.md - 2),
                child: MeshWallpaperView(
                  spec: spec,
                  ground: chatix.chatBackground,
                  child: const _MiniConversation(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x1 + 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two bubble silhouettes, so a tile reads as a chat rather than as an
/// abstract swatch — the pattern has to be judged against the thing that
/// will sit on top of it.
class _MiniConversation extends StatelessWidget {
  const _MiniConversation();

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.x2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bubble(width: 46, color: chatix.bubbleIncoming),
          const SizedBox(height: AppSpacing.x1 + 1),
          Align(
            alignment: Alignment.centerRight,
            child: _bubble(width: 38, gradient: chatix.bubbleOutgoingGradient),
          ),
        ],
      ),
    );
  }

  Widget _bubble({required double width, Color? color, Gradient? gradient}) =>
      Container(
        width: width,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      );
}
