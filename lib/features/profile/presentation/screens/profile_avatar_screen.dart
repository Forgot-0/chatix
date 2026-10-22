import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/utils/media_viewer_navigation.dart';
import 'package:chatix/features/chat/presentation/widgets/media_viewer/viewer_chrome.dart';
import 'package:chatix/features/profile/domain/entities/profile_photo.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_photos_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Somebody's photos, full screen and zoomable: the current one first, and
/// the ones before it a swipe away — the history `GET /profiles/{id}/photos/`
/// keeps (api-docs §4.5.1).
///
/// On one's own photos the bar also offers to bring an old one back to the
/// front or to delete one. Always dark, in both themes: the picture is the
/// whole screen, and a light surround would tint how it reads — the chat
/// media viewer does the same for the same reason.
class ProfileAvatarScreen extends ConsumerWidget {
  const ProfileAvatarScreen({super.key, this.profileId});

  /// Null means the signed-in user's own photos.
  final int? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final resolvedId = profileId ?? myUserId;

    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: resolvedId == null
          ? Scaffold(
              backgroundColor: AppPalette.viewerGround,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                foregroundColor: AppPalette.onMediaScrim,
              ),
              body: Center(child: Text(l10n.signInToViewProfile)),
            )
          : _PhotoViewer(profileId: resolvedId, isMine: resolvedId == myUserId),
    );
  }
}

/// Where a photo's pixels come from: the network cache, keyed by the
/// object rather than by the URL — the URL is re-signed on every read, the
/// key is the photo's own (api-docs §4.3). A test hands over bytes instead.
final profilePhotoImageProvider = Provider<ImageProvider Function(String url)>(
  (ref) =>
      (url) => CachedNetworkImageProvider(
        url,
        cacheKey: ProfilePhoto.cacheKeyOf(url),
      ),
);

enum _PhotoAction { makeMain, delete }

class _PhotoViewer extends ConsumerStatefulWidget {
  const _PhotoViewer({required this.profileId, required this.isMine});

  final int profileId;
  final bool isMine;

  @override
  ConsumerState<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<_PhotoViewer> {
  final PageController _pages = PageController();
  int _index = 0;
  bool _isZoomed = false;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go(ProfileRoute.location);

  void _goTo(int index, int count) {
    if (index < 0 || index >= count || index == _index) return;
    _pages.animateToPage(
      index,
      duration: AppMotion.base,
      curve: AppMotion.standard,
    );
  }

  Future<void> _act(_PhotoAction action, ProfilePhoto photo, int count) async {
    final l10n = AppLocalizations.of(context);
    final actions = ref.read(profilePhotoActionsProvider);

    if (action == _PhotoAction.delete) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.profilePhotoDeleteTitle),
          content: Text(
            photo.isMain
                ? l10n.profilePhotoDeleteCurrentBody
                : l10n.profilePhotoDeleteBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
                foregroundColor: Theme.of(dialogContext).colorScheme.onError,
              ),
              child: Text(l10n.profilePhotoDelete),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _busy = true);
    final failure = switch (action) {
      _PhotoAction.makeMain => await actions.makeMain(
        widget.profileId,
        photo.id,
      ),
      _PhotoAction.delete => await actions.delete(widget.profileId, photo.id),
    };
    if (!mounted) return;
    setState(() => _busy = false);

    if (failure != null) {
      AppSnackbar.failure(context, friendlyFailureMessage(failure, l10n: l10n));
      return;
    }

    switch (action) {
      case _PhotoAction.makeMain:
        AppSnackbar.quiet(context, l10n.profilePhotoMadeMain);
        // It is first in the history now; follow it there.
        _pages.jumpToPage(0);
      case _PhotoAction.delete:
        AppSnackbar.quiet(context, l10n.profilePhotoDeleted);
        // The last one gone: there is nothing left to look at.
        if (count <= 1) _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileDetailProvider(widget.profileId));
    final photos =
        ref.watch(profilePhotosProvider(widget.profileId)).value ?? const [];
    final profile = profileAsync.value;

    // The history when there is one; until it arrives — or where it could
    // not be read — the current photo the profile already carries, so the
    // screen never waits on a second request to show what it has.
    final slides = <_Slide>[
      for (final photo in photos)
        if (photo.bestUrl(512) case final url?) _Slide(url, photo),
    ];
    if (slides.isEmpty) {
      final url = profile?.bestAvatarUrl(512);
      if (url != null) slides.add(_Slide(url, null));
    }

    final index = slides.isEmpty ? 0 : _index.clamp(0, slides.length - 1);
    final current = slides.isEmpty ? null : slides[index];
    final photo = current?.photo;

    return Scaffold(
      backgroundColor: AppPalette.viewerGround,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppPalette.onMediaScrim,
        elevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: _close,
        ),
        title: _Title(
          title: slides.length > 1
              ? l10n.mediaViewerCounter(index + 1, slides.length)
              : l10n.profilePhoto,
          date: photo == null
              ? null
              : AppDateFormat.of(context).date(photo.createdAt.toLocal()),
        ),
        actions: [
          if (widget.isMine && photo != null)
            _busy
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.x4),
                    child: SizedBox.square(
                      dimension: MediaViewerLayout.spinnerSize - AppSpacing.x2,
                      child: CircularProgressIndicator(
                        strokeWidth: MediaViewerLayout.spinnerStroke,
                      ),
                    ),
                  )
                : PopupMenuButton<_PhotoAction>(
                    tooltip: l10n.profileActionMore,
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) => _act(action, photo, slides.length),
                    itemBuilder: (_) => [
                      if (!photo.isMain)
                        PopupMenuItem(
                          value: _PhotoAction.makeMain,
                          child: Text(l10n.profilePhotoMakeMain),
                        ),
                      PopupMenuItem(
                        value: _PhotoAction.delete,
                        child: Text(l10n.profilePhotoDelete),
                      ),
                    ],
                  ),
        ],
      ),
      body: profile == null && profileAsync.hasError
          ? AppErrorState(
              error: profileAsync.error,
              fallbackMessage: l10n.profileLoadFailed,
              retryLabel: l10n.retry,
              onRetry: () =>
                  ref.invalidate(profileDetailProvider(widget.profileId)),
            )
          : profile == null
          ? const _PhotoSkeleton()
          : slides.isEmpty
          ? Center(
              child: Text(
                l10n.profileNoPhoto,
                style: const TextStyle(color: AppPalette.onViewerMuted),
              ),
            )
          : CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
                    _goTo(index - 1, slides.length),
                const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
                    _goTo(index + 1, slides.length),
              },
              child: Focus(
                autofocus: true,
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      PageView.builder(
                        controller: _pages,
                        // A zoomed-in photo is being panned, not paged.
                        physics: _isZoomed
                            ? const NeverScrollableScrollPhysics()
                            : const PageScrollPhysics(),
                        itemCount: slides.length,
                        onPageChanged: (value) =>
                            setState(() => _index = value),
                        itemBuilder: (context, i) => _PhotoPage(
                          key: ValueKey(slides[i].photo?.id ?? slides[i].url),
                          image: ref.watch(profilePhotoImageProvider)(
                            slides[i].url,
                          ),
                          heroTag: i == 0
                              ? profileAvatarHeroTag(widget.profileId)
                              : null,
                          isCurrent: i == index,
                          onZoomChanged: (zoomed) {
                            if (_isZoomed != zoomed) {
                              setState(() => _isZoomed = zoomed);
                            }
                          },
                        ),
                      ),
                      // Arrows for a mouse, where there is room for them.
                      if (slides.length > 1 &&
                          constraints.maxWidth >=
                              MediaViewerLayout.wideFrom) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.x4),
                            child: ViewerSideArrow(
                              icon: Icons.chevron_left_rounded,
                              tooltip: l10n.mediaViewerPrevious,
                              onPressed: index > 0
                                  ? () => _goTo(index - 1, slides.length)
                                  : null,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.x4),
                            child: ViewerSideArrow(
                              icon: Icons.chevron_right_rounded,
                              tooltip: l10n.mediaViewerNext,
                              onPressed: index < slides.length - 1
                                  ? () => _goTo(index + 1, slides.length)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// One picture of the strip, and the photo it comes from — none while the
/// history is still on its way.
class _Slide {
  const _Slide(this.url, this.photo);

  final String url;
  final ProfilePhoto? photo;
}

/// "2 of 5", and under it the day that photo was put up.
class _Title extends StatelessWidget {
  const _Title({required this.title, this.date});

  final String title;
  final String? date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = this.date;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        if (date != null)
          Text(
            date,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.onViewerMuted,
            ),
          ),
      ],
    );
  }
}

/// One photo, zoomable — pinch, or a double tap about the point tapped.
class _PhotoPage extends StatefulWidget {
  const _PhotoPage({
    super.key,
    required this.image,
    required this.heroTag,
    required this.isCurrent,
    required this.onZoomChanged,
  });

  final ImageProvider image;

  /// Only the current photo flies in from the profile's face.
  final String? heroTag;

  final bool isCurrent;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_PhotoPage> createState() => _PhotoPageState();
}

class _PhotoPageState extends State<_PhotoPage> {
  final TransformationController _transform = TransformationController();
  Offset? _doubleTapAt;

  @override
  void didUpdateWidget(_PhotoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Swiped away: the next time this photo comes round it is whole again.
    if (oldWidget.isCurrent && !widget.isCurrent) {
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final size = context.size;
    final focal =
        _doubleTapAt ?? (size == null ? Offset.zero : size.center(Offset.zero));
    final zoomIn = !ViewerZoom.isZoomed(_transform.value);
    _transform.value = zoomIn
        ? ViewerZoom.about(focal, MediaViewerLayout.doubleTapScale)
        : Matrix4.identity();
    widget.onZoomChanged(zoomIn);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final heroTag = widget.heroTag;

    final picture = Image(
      image: widget.image,
      fit: BoxFit.contain,
      frameBuilder: (context, child, frame, synchronous) =>
          frame == null && !synchronous ? const _PhotoSkeleton() : child,
      errorBuilder: (_, _, _) => Center(
        child: Text(
          l10n.profileLoadFailed,
          style: const TextStyle(color: AppPalette.onViewerMuted),
        ),
      ),
    );

    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
      onDoubleTap: _onDoubleTap,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: MediaViewerLayout.maxScale,
        onInteractionEnd: (_) =>
            widget.onZoomChanged(ViewerZoom.isZoomed(_transform.value)),
        child: Center(
          child: heroTag == null
              ? picture
              : Hero(
                  tag: heroTag,
                  flightShuttleBuilder: profileAvatarHeroFlight,
                  child: picture,
                ),
        ),
      ),
    );
  }
}

/// A photo-shaped placeholder for the one screen that is nothing but a
/// photo.
class _PhotoSkeleton extends StatelessWidget {
  const _PhotoSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: AspectRatio(
          aspectRatio: 1,
          child: AppSkeleton(
            child: AppBone(height: double.infinity, radius: AppRadii.xl),
          ),
        ),
      ),
    );
  }
}
