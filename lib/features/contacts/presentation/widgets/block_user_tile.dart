import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/contacts/presentation/widgets/block_actions.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// "Block user" in the colour of things not undone with a tap — or, once
/// they are blocked, a plain "Unblock". The last row of a person's profile
/// and of a direct chat's info page.
class BlockUserTile extends ConsumerWidget {
  const BlockUserTile({super.key, required this.userId, required this.name});

  final int userId;

  /// What the dialog and the snackbar call them.
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isBlocked = ref.watch(isUserBlockedProvider(userId));
    final busy = ref.watch(isBlockBusyProvider(userId));
    final danger = ChatixTheme.of(context).danger;

    if (isBlocked) {
      return ListTile(
        leading: const Icon(Icons.lock_open_outlined),
        title: Text(l10n.unblockUserAction),
        enabled: !busy,
        onTap: () =>
            BlockActions.unblock(context, ref, userId: userId, name: name),
      );
    }

    return ListTile(
      leading: Icon(Icons.block, color: danger),
      title: Text(l10n.blockUserAction, style: TextStyle(color: danger)),
      enabled: !busy,
      onTap: () => BlockActions.block(context, ref, userId: userId, name: name),
    );
  }
}
