import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/typography/highlighted_text.dart';
import 'package:chatix/core/ui/widgets/app_swipe_actions.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_actions.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One person in the book: their face, the name the owner knows them by,
/// whether they are here right now — or their handle when that cannot be
/// known — and the mark of a contact who has added the owner back.
///
/// A tap opens the profile. The actions are a swipe away on a phone, a long
/// press or a right click everywhere.
class ContactTile extends ConsumerStatefulWidget {
  const ContactTile({
    super.key,
    required this.contact,
    this.query = '',
    this.showMessageButton = false,
  });

  final Contact contact;

  /// What was searched for, picked out of the name. Empty in the list.
  final String query;

  /// The search shows "Message" in the row itself.
  final bool showMessageButton;

  @override
  ConsumerState<ContactTile> createState() => _ContactTileState();
}

class _ContactTileState extends ConsumerState<ContactTile> {
  @override
  void initState() {
    super.initState();
    _requestPresence();
  }

  @override
  void didUpdateWidget(covariant ContactTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contact.userId != widget.contact.userId) _requestPresence();
  }

  /// Presence ships only with a chat's member list (api-docs §5.3), so only
  /// someone with a direct chat can be shown as online. The cache behind it
  /// decides whether that is a request.
  void _requestPresence() {
    final chatId = ref.read(directChatIdsProvider)[widget.contact.userId];
    if (chatId != null) {
      ref.read(chatPresenceProvider.notifier).ensureFresh(chatId);
    }
  }

  void _run(ContactAction action) =>
      ContactActions.run(context, ref, widget.contact, action);

  Future<void> _openSheet() async {
    final action = await ContactActions.showSheet(context, widget.contact);
    if (action != null && mounted) _run(action);
  }

  Future<void> _openMenu(Offset position) async {
    final action = await ContactActions.showMenuAt(
      context,
      widget.contact,
      position,
    );
    if (action != null && mounted) _run(action);
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    final l10n = AppLocalizations.of(context);
    final isOnline = ref.watch(contactOnlineProvider(contact.userId));
    final name = contactNameOf(contact, l10n);

    final row = _PersonRow(
      avatar: contactAvatar(
        contact.profile,
        userId: contact.userId,
        name: name,
        isOnline: isOnline,
        onlineLabel: l10n.contactsOnline,
      ),
      name: name,
      query: widget.query,
      isMutual: contact.isMutual,
      subtitle: isOnline == true
          ? _Subtitle.online(l10n.contactsOnline)
          : _Subtitle.handle(contact.username),
      onTap: () => context.push(ProfileDetailRoute(contact.userId).location),
      onLongPress: _openSheet,
      onSecondaryTap: _openMenu,
      trailing: widget.showMessageButton
          ? _MessageButton(onPressed: () => _run(ContactAction.message))
          : null,
    );

    final (leading, trailing) = ContactActions.swipeActions(
      context,
      contact,
      _run,
    );

    return Semantics(
      hint: l10n.contactsMoreActions,
      child: AppSwipeActions(leading: leading, trailing: trailing, child: row),
    );
  }
}

/// Somebody the global search found outside the book: tap for the profile,
/// "Message" to write to them straight away.
class PersonResultTile extends ConsumerWidget {
  const PersonResultTile({super.key, required this.hit, this.query = ''});

  final ContactSearchHit hit;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final profile = hit.profile;
    final name = contactProfileNameOf(profile, l10n);
    final displayName = profile?.displayName?.trim() ?? '';

    return _PersonRow(
      avatar: contactAvatar(profile, userId: hit.userId, name: name),
      name: name,
      query: ContactSearchQuery.stripAt(query),
      isMutual: false,
      // The handle is the title already when there is no name.
      subtitle: _Subtitle.handle(
        displayName.isEmpty ? null : profile?.username,
      ),
      onTap: () => context.push(ProfileDetailRoute(hit.userId).location),
      trailing: _MessageButton(
        onPressed: () => ContactActions.openChat(context, ref, hit.userId),
      ),
    );
  }
}

/// The second line: "online" in the accent, or the handle, or nothing.
class _Subtitle {
  const _Subtitle._(this.text, {required this.isAccent});

  factory _Subtitle.online(String label) => _Subtitle._(label, isAccent: true);

  static _Subtitle? handle(String? username) {
    final value = username?.trim();
    if (value == null || value.isEmpty) return null;
    return _Subtitle._('@$value', isAccent: false);
  }

  final String text;
  final bool isAccent;
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.avatar,
    required this.name,
    required this.query,
    required this.isMutual,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.trailing,
  });

  final Widget avatar;
  final String name;
  final String query;
  final bool isMutual;
  final _Subtitle? subtitle;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Offset>? onSecondaryTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chatix = ChatixTheme.of(context);
    final line = subtitle;

    final titleStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onSecondaryTapUp: onSecondaryTap == null
            ? null
            : (details) => onSecondaryTap!(details.globalPosition),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.x4,
              vertical: AppSpacing.x1 + chatix.density.listRowPadding,
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: query.trim().isEmpty
                                ? Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: titleStyle,
                                  )
                                : HighlightedText(
                                    text: name,
                                    query: query.trim(),
                                    maxLines: 1,
                                    style: titleStyle,
                                  ),
                          ),
                          if (isMutual) ...[
                            const SizedBox(width: AppSpacing.x1),
                            Tooltip(
                              message: l10n.contactsMutual,
                              child: Icon(
                                Icons.people_alt_rounded,
                                size: ContactsLayout.mutualIcon,
                                color: scheme.secondary,
                                semanticLabel: l10n.contactsMutual,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (line != null) ...[
                        const SizedBox(height: ContactsLayout.lineGap),
                        Text(
                          line.text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: line.isAccent
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing case final action?) ...[
                  const SizedBox(width: AppSpacing.x3),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  const _MessageButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      ),
      child: Text(AppLocalizations.of(context).sendMessageAction),
    );
  }
}
