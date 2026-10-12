import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_switch_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Ctrl+K: a search box over the window, and the chats whose names match.
///
/// A way to a conversation by its name, for when the list is long and the
/// hands are on the keyboard. It only looks through chats this device has
/// already loaded — the list and, once fetched, the archive — so it answers
/// on the keystroke; people and messages are the search screen's job.
class ChatJumpPalette extends ConsumerStatefulWidget {
  const ChatJumpPalette({super.key});

  /// Opens the palette. Resolves to the picked chat's id, or null when it is
  /// closed without a pick.
  static Future<String?> show(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => const ChatJumpPalette(),
  );

  /// [chats] narrowed to those whose title matches [query], best first:
  /// titles that start with it, then titles with a word that does, then the
  /// rest. Within each group the list's own order holds, so the chat that is
  /// higher in the list is higher here.
  static List<ChatEntity> rank(
    List<ChatEntity> chats,
    String query,
    String Function(ChatEntity chat) titleOf,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return chats;

    final starts = <ChatEntity>[];
    final words = <ChatEntity>[];
    final contains = <ChatEntity>[];

    for (final chat in chats) {
      final title = titleOf(chat).toLowerCase();
      if (title.startsWith(needle)) {
        starts.add(chat);
      } else if (title.contains(' $needle')) {
        words.add(chat);
      } else if (title.contains(needle)) {
        contains.add(chat);
      }
    }
    return [...starts, ...words, ...contains];
  }

  @override
  ConsumerState<ChatJumpPalette> createState() => _ChatJumpPaletteState();
}

class _ChatJumpPaletteState extends ConsumerState<ChatJumpPalette> {
  final _query = TextEditingController();
  final _scroll = ScrollController();

  /// The row Enter opens: moved by the arrows and by the mouse.
  int _highlight = 0;

  @override
  void initState() {
    super.initState();
    _query.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _query.removeListener(_onQueryChanged);
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() => _highlight = 0);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Every chat the palette can reach, in the order the list draws them,
  /// the archive after the rest.
  List<ChatEntity> _candidates() {
    final listed = ref.watch(chatListProvider).value?.items ?? const [];
    final byId = {for (final chat in listed) chat.id: chat};

    final ordered = [
      for (final id in ref.watch(visibleChatOrderProvider))
        if (byId[id] != null) byId[id]!,
    ];

    // Only once it has been fetched: opening the palette is no reason to
    // start a request for chats the reader put away.
    if (!ref.exists(archivedChatListProvider)) return ordered;

    final archived =
        ref.watch(archivedChatListProvider).value?.items ?? const [];
    final seen = {for (final chat in ordered) chat.id};
    return [
      ...ordered,
      for (final chat in archived)
        if (!seen.contains(chat.id)) chat,
    ];
  }

  void _move(int by, int count) {
    if (count == 0) return;
    setState(() => _highlight = (_highlight + by).clamp(0, count - 1));
    _revealHighlight();
  }

  /// Keeps the highlighted row in view as the arrows walk past the edge.
  void _revealHighlight() {
    if (!_scroll.hasClients) return;

    final position = _scroll.position;
    final top = _highlight * DesktopSizes.paletteRowHeight;
    final bottom = top + DesktopSizes.paletteRowHeight;

    if (top < position.pixels) {
      _scroll.jumpTo(top);
    } else if (bottom > position.pixels + position.viewportDimension) {
      _scroll.jumpTo(bottom - position.viewportDimension);
    }
  }

  void _pick(ChatEntity chat) => Navigator.of(context).pop(chat.id);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
    String titleOf(ChatEntity chat) => chatTitleOf(
      chat,
      l10n,
      myUserId: myUserId,
      peerLocalName: readPeerLocalName(ref, chat, myUserId),
    );

    final matches = ChatJumpPalette.rank(_candidates(), _query.text, titleOf);
    final highlight = matches.isEmpty
        ? -1
        : _highlight.clamp(0, matches.length - 1);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        DesktopSizes.paletteTopInset,
        AppSpacing.x4,
        AppSpacing.x4,
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: DesktopSizes.paletteMaxWidth,
        ),
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
                _move(1, matches.length),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
                _move(-1, matches.length),
            const SingleActivator(LogicalKeyboardKey.enter): () {
              if (highlight >= 0) _pick(matches[highlight]);
            },
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () {
              if (highlight >= 0) _pick(matches[highlight]);
            },
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x1,
                ),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.go,
                  style: theme.textTheme.titleMedium,
                  decoration: InputDecoration(
                    hintText: l10n.chatJumpHint,
                    prefixIcon: const Icon(Icons.search),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: matches.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.x6),
                        child: Text(
                          l10n.chatJumpNothingFound,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxHeight: DesktopSizes.paletteMaxListHeight,
                        ),
                        child: ListView.builder(
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x1,
                          ),
                          itemExtent: DesktopSizes.paletteRowHeight,
                          itemCount: matches.length,
                          itemBuilder: (context, index) => _PaletteRow(
                            chat: matches[index],
                            title: titleOf(matches[index]),
                            myUserId: myUserId,
                            isHighlighted: index == highlight,
                            onHover: () {
                              if (_highlight != index) {
                                setState(() => _highlight = index);
                              }
                            },
                            onTap: () => _pick(matches[index]),
                          ),
                        ),
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x2,
                ),
                child: Text(
                  l10n.chatJumpFooter,
                  style: theme.textTheme.labelSmall?.copyWith(
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

class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.chat,
    required this.title,
    required this.myUserId,
    required this.isHighlighted,
    required this.onHover,
    required this.onTap,
  });

  final ChatEntity chat;
  final String title;
  final int? myUserId;
  final bool isHighlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unread = chat.unreadCount ?? 0;

    return Material(
      color: isHighlighted ? scheme.secondaryContainer : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onHover: (hovering) {
          if (hovering) onHover();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          child: Row(
            children: [
              ChatRowAvatar(
                chat: chat,
                myUserId: myUserId,
                size: ChatAvatarSize.md,
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isHighlighted
                        ? scheme.onSecondaryContainer
                        : scheme.onSurface,
                  ),
                ),
              ),
              if (unread > 0) ...[
                const SizedBox(width: AppSpacing.x2),
                UnreadBadge(count: unread, isMuted: chat.isMutedByMe),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
