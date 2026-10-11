import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/core/ui/widgets/app_swipe_actions.dart';
import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/features/contacts/presentation/widgets/block_actions.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Settings → Privacy → Blocked users: `GET /contacts/blocked/`, a page at a
/// time by `after_target_id` (api-docs §4.13), each row with its way out —
/// a button, or a swipe.
///
/// The note at the top is not decoration. The server keeps the list but does
/// not act on it yet ("этап 2"): a blocked person can still write, and the
/// list is where somebody goes to find out what blocking actually did.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final list = ref.watch(blockedUsersListProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.blockedUsersTitle)),
      body: AppContentWidth(
        maxWidth: ContactsLayout.maxWidth,
        child: list.when(
          loading: () => const AppListSkeleton(),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: l10n.blockedUsersLoadFailed,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(blockedUsersListProvider),
          ),
          data: (state) => _BlockedList(state: state),
        ),
      ),
    );
  }
}

class _BlockedList extends ConsumerWidget {
  const _BlockedList({required this.state});

  final BlockedUsersListState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final controller = ref.read(blockedUsersListProvider.notifier);

    // The rows read so far, less whoever has been unblocked since — here or
    // anywhere else. An unblock the server refuses puts its row back.
    final blocked = ref.watch(blockedUserIdsProvider);
    final rows = [
      for (final user in state.users)
        if (blocked.contains(user.userId)) user,
    ];

    if (rows.isEmpty && !state.hasNext) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: AppEmptyState(
          illustration: AppIllustrationKind.people,
          title: l10n.blockedUsersEmptyTitle,
          message: l10n.blockedUsersEmptyMessage,
        ),
      );
    }

    final hasFooter =
        state.hasNext || state.isLoadingMore || state.loadMoreFailure != null;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: 1 + rows.length + (hasFooter ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) return const _ServerNote();
          final i = index - 1;
          if (i < rows.length) {
            return _BlockedUserTile(
              key: ValueKey<int>(rows[i].userId),
              user: rows[i],
            );
          }
          return _Footer(state: state, onLoadMore: controller.loadMore);
        },
      ),
    );
  }
}

/// What blocking does today, before the list of whom it was done to.
class _ServerNote extends StatelessWidget {
  const _ServerNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x3,
        AppSpacing.x4,
        AppSpacing.x2,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: ContactsLayout.noteIcon,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).blockedUsersNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockedUserTile extends ConsumerWidget {
  const _BlockedUserTile({super.key, required this.user});

  final BlockedUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final chatix = ChatixTheme.of(context);
    final busy = ref.watch(isBlockBusyProvider(user.userId));
    final name = contactProfileNameOf(user.profile, l10n);
    final displayName = user.profile?.displayName?.trim() ?? '';

    void unblock() =>
        BlockActions.unblock(context, ref, userId: user.userId, name: name);

    final row = PersonRow(
      avatar: contactAvatar(user.profile, userId: user.userId, name: name),
      name: name,
      // The handle is the title already when there is no name.
      subtitle: PersonRowSubtitle.handle(
        displayName.isEmpty ? null : user.profile?.username,
      ),
      onTap: () => context.push(ProfileDetailRoute(user.userId).location),
      trailing: OutlinedButton(
        onPressed: busy ? null : unblock,
        style: OutlinedButton.styleFrom(
          visualDensity: VisualDensity.compact,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
        ),
        child: Text(l10n.unblockUserAction),
      ),
    );

    return AppSwipeActions(
      enabled: !busy,
      trailing: [
        SwipeAction(
          icon: Icons.lock_open_outlined,
          label: l10n.unblockUserAction,
          background: chatix.success,
          foreground: AppContrast.foregroundOn(chatix.success),
          onPressed: unblock,
        ),
      ],
      child: row,
    );
  }
}

/// The end of what has been read: more on its way, a retry, or — once it is
/// built, which is when the reader is near it — the request for the next
/// page.
class _Footer extends StatelessWidget {
  const _Footer({required this.state, required this.onLoadMore});

  final BlockedUsersListState state;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    final failure = state.loadMoreFailure;
    if (failure != null && !state.isLoadingMore) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.x4),
        child: AppInlineError(
          error: failure,
          fallbackMessage: AppLocalizations.of(
            context,
          ).blockedUsersLoadMoreFailed,
          onRetry: onLoadMore,
        ),
      );
    }

    if (state.canLoadMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onLoadMore());
    }

    return const Padding(
      padding: EdgeInsets.all(AppSpacing.x4),
      child: Center(
        child: SizedBox.square(
          dimension: AppSpacing.x6,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
