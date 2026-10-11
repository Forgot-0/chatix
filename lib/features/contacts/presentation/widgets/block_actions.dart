import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_dialogs.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Blocking and unblocking, written once for every place that offers them:
/// a profile, a direct chat's "⋮" and the bar that replaces its composer, a
/// contact's long press, and the block list itself.
abstract final class BlockActions {
  /// Asks first, then blocks [userId]. Answers whether the block went
  /// through.
  static Future<bool> block(
    BuildContext context,
    WidgetRef ref, {
    required int userId,
    required String name,
  }) async {
    final confirmed = await showBlockUserDialog(context, name);
    if (!confirmed || !context.mounted) return false;

    final l10n = AppLocalizations.of(context);
    // The row or sheet this came from may be gone by the time the server
    // answers; the screen around it is still there to hear how it went.
    final host = Navigator.of(context).context;
    final notifier = ref.read(blockListProvider.notifier);

    final result = await notifier.block(userId);
    if (!host.mounted) return result.isRight();

    result.match(
      (failure) => AppSnackbar.failure(
        host,
        blockFailureMessage(failure, l10n, blocking: true),
      ),
      (_) => AppSnackbar.quiet(host, l10n.blockUserDone(name)),
    );
    return result.isRight();
  }

  /// Unblocks [userId] straight away: lifting a block takes nothing from
  /// anybody, so it is not asked about.
  static Future<bool> unblock(
    BuildContext context,
    WidgetRef ref, {
    required int userId,
    required String name,
  }) async {
    final l10n = AppLocalizations.of(context);
    final host = Navigator.of(context).context;
    final notifier = ref.read(blockListProvider.notifier);

    final result = await notifier.unblock(userId);
    if (!host.mounted) return result.isRight();

    result.match(
      (failure) => AppSnackbar.failure(
        host,
        blockFailureMessage(failure, l10n, blocking: false),
      ),
      (_) => AppSnackbar.quiet(host, l10n.unblockUserDone(name)),
    );
    return result.isRight();
  }
}

/// The sentence for a block or unblock that did not go through.
String blockFailureMessage(
  Failure failure,
  AppLocalizations l10n, {
  required bool blocking,
}) {
  if (failure is SelfContactFailure) return l10n.blockErrorSelf;
  return friendlyFailureMessage(
    failure,
    l10n: l10n,
    fallback: blocking ? l10n.blockUserFailed : l10n.unblockUserFailed,
  );
}
