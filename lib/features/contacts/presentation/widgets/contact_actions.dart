import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_swipe_actions.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/direct_chat_opener.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/features/contacts/presentation/widgets/block_actions.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_dialogs.dart';
import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What can be done to a contact from its row. Swiped: the first five.
/// Long-pressed or right-clicked: those and blocking, which is one of the
/// two depending on whether the person is blocked already.
enum ContactAction { message, call, favorite, rename, delete, block, unblock }

/// The contact actions, written once for the list, the search and the
/// profile.
abstract final class ContactActions {
  /// People whose chat is being found or created right now, so a second tap
  /// does not make a second chat (api-docs §5.2: duplicates are possible).
  static final Set<int> _opening = <int>{};

  static Future<void> run(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
    ContactAction action,
  ) {
    return switch (action) {
      ContactAction.message => openChat(context, ref, contact.userId),
      ContactAction.call => openChat(context, ref, contact.userId, call: true),
      ContactAction.favorite => toggleFavorite(context, ref, contact),
      ContactAction.rename => rename(context, contact),
      ContactAction.delete => delete(context, ref, contact),
      ContactAction.block => BlockActions.block(
        context,
        ref,
        userId: contact.userId,
        name: contactNameOf(contact, AppLocalizations.of(context)),
      ),
      ContactAction.unblock => BlockActions.unblock(
        context,
        ref,
        userId: contact.userId,
        name: contactNameOf(contact, AppLocalizations.of(context)),
      ),
    };
  }

  /// The 1:1 chat with [userId] — found among the loaded chats or created —
  /// and its call screen when [call]: a call is a room inside a chat, there
  /// is no person-to-person call endpoint (api-docs §5.6).
  static Future<void> openChat(
    BuildContext context,
    WidgetRef ref,
    int userId, {
    bool call = false,
  }) async {
    if (!_opening.add(userId)) return;
    try {
      final result = await resolveDirectChatWith(ref, userId);
      if (!context.mounted) return;

      final l10n = AppLocalizations.of(context);
      result.match(
        (failure) => AppSnackbar.failure(
          context,
          chatFailureMessage(failure) ??
              friendlyFailureMessage(
                failure,
                l10n: l10n,
                fallback: l10n.startChatFailed,
              ),
        ),
        (chatId) => context.push(
          call
              ? ChatCallRoute.locationOf(chatId)
              : ChatDetailRoute(chatId).location,
        ),
      );
    } finally {
      _opening.remove(userId);
    }
  }

  static Future<void> toggleFavorite(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
  ) async {
    final result = await ref
        .read(contactsProvider.notifier)
        .setFavorite(contact.userId, !contact.isFavorite);
    if (!context.mounted) return;

    result.match(
      (failure) => AppSnackbar.failure(
        context,
        contactFailureMessage(failure, AppLocalizations.of(context)),
      ),
      (_) {},
    );
  }

  static Future<void> rename(BuildContext context, Contact contact) =>
      showRenameContactDialog(context, contact);

  static Future<void> delete(
    BuildContext context,
    WidgetRef ref,
    Contact contact,
  ) async {
    final l10n = AppLocalizations.of(context);
    final name = contactNameOf(contact, l10n);

    final confirmed = await showDeleteContactDialog(context, name);
    if (!confirmed || !context.mounted) return;

    // The row leaves the list as soon as the delete is asked for, taking
    // [context] with it: the answer is reported from the screen around it.
    final host = Navigator.of(context).context;

    final result = await ref
        .read(contactsProvider.notifier)
        .remove(contact.userId);
    if (!host.mounted) return;

    result.match((failure) {
      // Gone already: the book now agrees, which is what was asked for.
      if (failure is ContactNotFoundFailure) {
        AppSnackbar.quiet(host, l10n.contactsDeleted(name));
        return;
      }
      AppSnackbar.failure(host, contactFailureMessage(failure, l10n));
    }, (_) => AppSnackbar.quiet(host, l10n.contactsDeleted(name)));
  }

  /// Adds the person whose profile is open, under their own name — it can be
  /// changed afterwards, as in Telegram.
  static Future<void> addUser(
    BuildContext context,
    WidgetRef ref, {
    required int userId,
  }) async {
    final result = await ref
        .read(contactsProvider.notifier)
        .add(userId: userId);
    if (!context.mounted) return;

    final l10n = AppLocalizations.of(context);
    result.match(
      (failure) =>
          AppSnackbar.failure(context, contactFailureMessage(failure, l10n)),
      (contact) => AppSnackbar.quiet(
        context,
        l10n.contactsAdded(contactNameOf(contact, l10n)),
      ),
    );
  }

  static Future<void> addByUsername(
    BuildContext context, {
    String? username,
  }) async {
    final contact = await showAddContactDialog(
      context,
      initialUsername: username,
    );
    if (contact == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    AppSnackbar.quiet(
      context,
      l10n.contactsAdded(contactNameOf(contact, l10n)),
    );
  }

  /// Shares an invitation to find the owner here; the clipboard where the
  /// platform has no share sheet.
  static Future<void> invite(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final me = ref.read(authProvider).value;
    if (me == null) return;

    final text = l10n.contactsInviteMessage(
      me.username,
      ProfileShareLink.of(me.username),
    );

    final sharer = ref.read(fileSharerProvider);
    if (sharer.isSupported) {
      final box = context.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      try {
        await sharer.shareText(text, origin: origin);
        return;
      } catch (_) {
        // No share sheet after all: the clipboard still works.
      }
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    AppSnackbar.quiet(context, l10n.contactsInviteCopied);
  }

  static Future<void> import(BuildContext context) async {
    final result = await showImportContactsDialog(context);
    if (result == null || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    AppSnackbar.quiet(
      context,
      result.status == ContactImportStatus.queued
          ? l10n.contactsImportQueued(result.accepted)
          : l10n.contactsImportResult(
              result.matched,
              result.pending,
              result.invalid,
            ),
    );
  }

  /// The swipe buttons: write and call one way, favourite, rename and delete
  /// the other — the reversible ones nearest the thumb.
  static (List<SwipeAction>, List<SwipeAction>) swipeActions(
    BuildContext context,
    Contact contact,
    void Function(ContactAction action) onAction,
  ) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final chatix = ChatixTheme.of(context);

    final leading = [
      SwipeAction(
        icon: Icons.chat_bubble_outline,
        label: l10n.sendMessageAction,
        background: scheme.primary,
        foreground: scheme.onPrimary,
        onPressed: () => onAction(ContactAction.message),
      ),
      SwipeAction(
        icon: Icons.call_outlined,
        label: l10n.contactsActionCall,
        background: chatix.success,
        foreground: AppContrast.foregroundOn(chatix.success),
        onPressed: () => onAction(ContactAction.call),
      ),
    ];
    final trailing = [
      SwipeAction(
        icon: contact.isFavorite ? Icons.star : Icons.star_outline,
        label: contact.isFavorite
            ? l10n.contactsActionUnfavorite
            : l10n.contactsActionFavorite,
        background: chatix.attention,
        foreground: AppContrast.foregroundOn(chatix.attention),
        onPressed: () => onAction(ContactAction.favorite),
      ),
      SwipeAction(
        icon: Icons.edit_outlined,
        label: l10n.contactsActionRename,
        background: scheme.secondaryContainer,
        foreground: scheme.onSecondaryContainer,
        onPressed: () => onAction(ContactAction.rename),
      ),
      SwipeAction(
        icon: Icons.person_remove_outlined,
        label: l10n.contactsActionDelete,
        background: chatix.danger,
        foreground: AppContrast.foregroundOn(chatix.danger),
        onPressed: () => onAction(ContactAction.delete),
      ),
    ];
    return (leading, trailing);
  }

  /// The long-press sheet: the person's name over the actions.
  static Future<ContactAction?> showSheet(
    BuildContext context,
    Contact contact, {
    required bool isBlocked,
  }) {
    final l10n = AppLocalizations.of(context);

    // Taller than the default 9/16 of the screen allows on a phone, so the
    // sheet takes the height it needs — and scrolls where there is none.
    return showModalBottomSheet<ContactAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  0,
                  AppSpacing.x4,
                  AppSpacing.x2,
                ),
                child: Text(
                  contactNameOf(contact, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.titleMedium,
                ),
              ),
              for (final entry in _entries(
                sheetContext,
                contact,
                isBlocked: isBlocked,
              ))
                ListTile(
                  leading: Icon(entry.icon, color: entry.color),
                  title: Text(
                    entry.label,
                    style: entry.color == null
                        ? null
                        : TextStyle(color: entry.color),
                  ),
                  onTap: () => Navigator.of(sheetContext).pop(entry.action),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The right-click menu, opened where the pointer is.
  static Future<ContactAction?> showMenuAt(
    BuildContext context,
    Contact contact,
    Offset globalPosition, {
    required bool isBlocked,
  }) {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;

    return showMenu<ContactAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & Size.zero,
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(
        minWidth: AppMenuSizes.minWidth,
        maxWidth: AppMenuSizes.maxWidth,
      ),
      items: [
        for (final entry in _entries(context, contact, isBlocked: isBlocked))
          PopupMenuItem<ContactAction>(
            value: entry.action,
            child: Row(
              children: [
                Icon(
                  entry.icon,
                  size: AppMenuSizes.iconSize,
                  color: entry.color,
                ),
                const SizedBox(width: AppMenuSizes.iconGap),
                Expanded(
                  child: Text(
                    entry.label,
                    style: entry.color == null
                        ? null
                        : TextStyle(color: entry.color),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static List<_Entry> _entries(
    BuildContext context,
    Contact contact, {
    required bool isBlocked,
  }) {
    final l10n = AppLocalizations.of(context);
    final danger = ChatixTheme.of(context).danger;

    return [
      _Entry(
        ContactAction.message,
        Icons.chat_bubble_outline,
        l10n.sendMessageAction,
      ),
      _Entry(ContactAction.call, Icons.call_outlined, l10n.contactsActionCall),
      _Entry(
        ContactAction.favorite,
        contact.isFavorite ? Icons.star : Icons.star_outline,
        contact.isFavorite
            ? l10n.contactsActionUnfavorite
            : l10n.contactsActionFavorite,
      ),
      _Entry(
        ContactAction.rename,
        Icons.edit_outlined,
        l10n.contactsActionRename,
      ),
      _Entry(
        ContactAction.delete,
        Icons.person_remove_outlined,
        l10n.contactsActionDelete,
        color: danger,
      ),
      if (isBlocked)
        _Entry(
          ContactAction.unblock,
          Icons.lock_open_outlined,
          l10n.unblockUserAction,
        )
      else
        _Entry(
          ContactAction.block,
          Icons.block,
          l10n.blockUserAction,
          color: danger,
        ),
    ];
  }
}

class _Entry {
  const _Entry(this.action, this.icon, this.label, {this.color});

  final ContactAction action;
  final IconData icon;
  final String label;
  final Color? color;
}
