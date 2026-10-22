import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/profile/presentation/providers/profile_photos_provider.dart';
import 'package:chatix/features/profile/presentation/screens/profile_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a profile link (`/u/{username}`) opens: the person behind the
/// handle, on the same profile page every other way in leads to.
///
/// The handle is looked up first (`GET /profiles/u/{username}/`, public,
/// case aside — api-docs §4.3) and the page then takes over by id. A handle
/// nobody has — never had, or gave up — says so in so many words, which is
/// what a link that outlived a rename should do.
class UsernameProfileScreen extends ConsumerWidget {
  const UsernameProfileScreen({super.key, required this.username});

  /// As it came in the link, `@` or not.
  final String username;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final key = usernameKey(username);
    final handle = '@$key';

    return ref
        .watch(profileByUsernameProvider(key))
        .when(
          data: (profile) => ProfileScreen(profileId: profile.id),
          loading: () => Scaffold(
            appBar: AppBar(title: Text(handle)),
            body: const AppListSkeleton(),
          ),
          error: (error, _) => Scaffold(
            appBar: AppBar(title: Text(handle)),
            body: isUnknownUsername(error)
                ? AppEmptyState(
                    illustration: AppIllustrationKind.people,
                    title: l10n.profileByUsernameNotFound(handle),
                    message: l10n.profileByUsernameNotFoundHint,
                  )
                : AppErrorState(
                    error: error,
                    fallbackMessage: l10n.profileLoadFailed,
                    retryLabel: l10n.retry,
                    onRetry: () =>
                        ref.invalidate(profileByUsernameProvider(key)),
                  ),
          ),
        );
  }
}
