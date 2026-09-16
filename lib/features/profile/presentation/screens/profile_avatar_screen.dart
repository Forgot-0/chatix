import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Somebody's avatar, full screen and zoomable.
///
/// Always dark, in both themes: the picture is the whole screen, and a light
/// surround would tint how it reads. That is the one place in the app where
/// the theme does not decide the background — the chat media viewer does the
/// same thing for the same reason.
class ProfileAvatarScreen extends ConsumerWidget {
  const ProfileAvatarScreen({super.key, this.profileId});

  /// Null means the signed-in user's own avatar.
  final int? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    final resolvedId = profileId ?? myUserId;

    return Theme(
      data: ThemeData.dark(useMaterial3: true),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(l10n.profilePhoto),
          leading: IconButton(
            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            icon: const Icon(Icons.close),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(ProfileRoute.location),
          ),
        ),
        body: resolvedId == null
            ? Center(child: Text(l10n.signInToViewProfile))
            : _Body(profileId: resolvedId),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.profileId});

  final int profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profileAsync = ref.watch(profileDetailProvider(profileId));

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => AppErrorState(
        error: error,
        fallbackMessage: l10n.profileLoadFailed,
        retryLabel: l10n.retry,
        onRetry: () => ref.invalidate(profileDetailProvider(profileId)),
      ),
      data: (profile) {
        // The largest variant the server generates, because this is the one
        // place the picture is shown at full size (api-docs §4.5).
        final url = profile.bestAvatarUrl(512);
        if (url == null) {
          return Center(
            child: Text(
              l10n.profileNoPhoto,
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        return Center(
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Hero(
              tag: profileAvatarHeroTag(profile.id),
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, _) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, _, _) => Center(
                  child: Text(
                    l10n.profileLoadFailed,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
