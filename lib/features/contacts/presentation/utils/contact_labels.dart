import 'package:flutter/material.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_failures.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What to call [contact] on screen: the local name, their own, their
/// handle — and, for a contact with none of those, a placeholder.
String contactNameOf(Contact contact, AppLocalizations l10n) =>
    contact.bestName ?? l10n.contactsUnknownPerson;

String contactProfileNameOf(ContactProfile? profile, AppLocalizations l10n) =>
    profile?.bestName ?? l10n.contactsUnknownPerson;

/// The sentence for a failure of the address book, in the reader's language.
String contactFailureMessage(
  Failure failure,
  AppLocalizations l10n, {
  String? fallback,
}) {
  return switch (failure) {
    SelfContactFailure() => l10n.contactsErrorSelf,
    ContactBlockedFailure() => l10n.contactsErrorBlocked,
    ContactLimitFailure(:final limit) => l10n.contactsErrorLimit(limit),
    ContactTargetNotFoundFailure() => l10n.contactsErrorNotFound,
    ContactNotFoundFailure() => l10n.contactsErrorGone,
    ContactNameTooLongFailure() => l10n.contactsErrorNameTooLong(
      Contact.maxNameLength,
    ),
    ImportBatchTooLargeFailure(:final limit) => l10n.contactsErrorBatch(
      limit ?? ContactImportLimits.maxBatch,
    ),
    IdentifierQuotaFailure() => l10n.contactsErrorQuota,
    ImportInProgressFailure() => l10n.contactsErrorImportBusy,
    ImportUnavailableFailure() => l10n.contactsErrorImportUnavailable,
    _ => friendlyFailureMessage(failure, l10n: l10n, fallback: fallback),
  };
}

/// A person's face from the slice of profile the contact endpoints send —
/// coloured and initialled by the same rules as everywhere else, so a
/// contact looks the same here, in a chat and on their profile.
ChatAvatar contactAvatar(
  ContactProfile? profile, {
  required int userId,
  required String name,
  ChatAvatarSize size = ChatAvatarSize.md,
  bool? isOnline,
  String? onlineLabel,
}) {
  return ChatAvatar(
    source: profile != null && profile.hasAvatar
        ? AvatarSource.variants(profile.avatars)
        : AvatarSource.none,
    userId: userId,
    name: name,
    size: size,
    isOnline: isOnline,
    onlineLabel: onlineLabel,
  );
}

/// The section heading over a group of rows: small capitals, quiet colour.
class ContactSectionHeader extends StatelessWidget {
  const ContactSectionHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x4,
          AppSpacing.x1,
        ),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
