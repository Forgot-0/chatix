import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Where the account is signed in, from `GET /users/sessions/`.
///
/// Read-only: ending a session is `DELETE /sessions/{id}/`, which the API gates
/// behind the admin permission `user:update` (api-docs §3.15). Offering a
/// "sign out this device" button here would only ever produce 403s, so the
/// screen shows what it can actually deliver.
class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final sessions = ref.watch(mySessionsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myDevices)),
      body: sessions.when(
        loading: () => const AppListSkeleton(),
        error: (error, _) => AppErrorState(
          error: error,
          fallbackMessage: l10n.devicesLoadFailed,
          onRetry: () => ref.invalidate(mySessionsProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l10n.noDevices));
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mySessionsProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _SessionTile(session: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final SessionEntity session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final lastActive = session.lastActivity;

    return ListTile(
      leading: Icon(
        session.isActive ? Icons.devices : Icons.devices_other_outlined,
        color: session.isActive
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      ),
      title: Text(session.label, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.isActive ? l10n.deviceActive : l10n.deviceInactive,
            style: theme.textTheme.labelSmall?.copyWith(
              color: session.isActive
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          if (lastActive != null)
            Text(
              l10n.deviceLastActive(
                MaterialLocalizations.of(
                  context,
                ).formatMediumDate(lastActive.toLocal()),
              ),
              style: theme.textTheme.labelSmall,
            ),
        ],
      ),
      isThreeLine: lastActive != null,
    );
  }
}
