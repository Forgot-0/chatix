import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_people.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Somebody on an exception list, by id — all the server keeps there
/// (api-docs §4.14).
///
/// From the address book when they are in it: the name the reader gave
/// them, no request. Otherwise their profile, asked for once and kept.
AsyncValue<NewChatMember> watchPrivacyPerson(
  WidgetRef ref,
  int userId,
  AppLocalizations l10n,
) {
  final contact = ref.watch(contactOfProvider(userId));
  if (contact != null) return AsyncData(newChatMemberOf(contact, l10n));

  return ref.watch(profileDetailProvider(userId)).whenData((profile) {
    final name = profile.displayName?.trim();
    return NewChatMember(
      userId: profile.id,
      name: name == null || name.isEmpty ? '@${profile.username}' : name,
      username: profile.username,
      avatars: profile.avatars,
    );
  });
}

/// One person on an exception list: face, name, handle, and the button
/// that takes them off it.
class PrivacyPersonRow extends ConsumerWidget {
  const PrivacyPersonRow({
    super.key,
    required this.userId,
    required this.onRemove,
  });

  final int userId;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final person = watchPrivacyPerson(ref, userId, l10n);
    final member =
        person.value ??
        NewChatMember(
          userId: userId,
          name: person.hasError ? l10n.contactsUnknownPerson : l10n.loading,
        );
    final username = member.username;
    final handle = username == null || member.name == '@$username'
        ? null
        : '@$username';

    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x4,
          vertical: AppSpacing.x2,
        ),
        child: Row(
          children: [
            newChatMemberAvatar(member, size: ChatAvatarSize.md),
            const SizedBox(width: SettingsLayout.plateGap),
            Expanded(
              child: AppGroupedTileText(title: member.name, subtitle: handle),
            ),
            IconButton(
              tooltip: l10n.privacyExceptionRemove,
              onPressed: onRemove,
              color: scheme.error,
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
