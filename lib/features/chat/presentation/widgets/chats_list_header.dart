import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/inputs/app_search_pill.dart';
import 'package:chatix/features/chat/presentation/providers/chats_connection_status_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_banners.dart';
import 'package:chatix/features/chat_organizer/presentation/widgets/folder_tabs_bar.dart';
import 'package:chatix/features/notification/presentation/widgets/notification_bell.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The top of the chats list: the title row, the search pill under it and
/// the folder strip under that.
///
/// One header, pinned and floating at once. The title row and the folders
/// stay put; the search pill between them is the part that gives way — it
/// slides up under the title as the list scrolls down, and back out as soon
/// as the list scrolls up again, wherever it is. That keeps search one flick
/// away without spending its row on every screen of rows.
class ChatsListHeaderDelegate extends SliverPersistentHeaderDelegate {
  const ChatsListHeaderDelegate({
    required this.topInset,
    required this.showFolders,
    required this.showNewChat,
  });

  /// The status bar's height: the header draws under it, so the screen does
  /// not need an app bar of its own.
  final double topInset;

  /// Whether the folder strip is drawn at all (see [FolderTabsBar]).
  final bool showFolders;

  /// Whether "new chat" sits in the title row. Off on a phone, where the
  /// round button over the list's corner is the way in.
  final bool showNewChat;

  double get _foldersExtent => showFolders ? FolderTabsBar.height : 0;

  @override
  double get minExtent =>
      topInset + ChatsListLayout.titleBarHeight + _foldersExtent;

  @override
  double get maxExtent => minExtent + ChatsListLayout.searchBlockHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;

    const searchBlock = ChatsListLayout.searchBlockHeight;
    final searchExtent = (searchBlock - shrinkOffset).clamp(0.0, searchBlock);

    // Rows passing under the header get a hairline to pass under — unless
    // the folder strip is there, which draws its own.
    final showRule = !showFolders && (overlapsContent || shrinkOffset > 0);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: ChatsListLayout.maxTextScale,
      child: Material(
        color: scheme.surface,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: showRule
                ? Border(bottom: BorderSide(color: scheme.outlineVariant))
                : null,
          ),
          child: Column(
            children: [
              SizedBox(height: topInset),
              SizedBox(
                height: ChatsListLayout.titleBarHeight,
                child: _TitleBar(showNewChat: showNewChat),
              ),
              SizedBox(
                height: searchExtent,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    minHeight: searchBlock,
                    maxHeight: searchBlock,
                    child: Opacity(
                      opacity: searchExtent / searchBlock,
                      child: const _SearchBlock(),
                    ),
                  ),
                ),
              ),
              if (showFolders) const FolderTabsBar(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(ChatsListHeaderDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      showFolders != oldDelegate.showFolders ||
      showNewChat != oldDelegate.showNewChat;
}

class _TitleBar extends StatelessWidget {
  const _TitleBar({required this.showNewChat});

  final bool showNewChat;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppSpacing.x4,
        end: AppSpacing.x2,
      ),
      child: Row(
        children: [
          const Expanded(child: ChatsListTitle()),
          IconButton(
            onPressed: () => context.push(ChatFoldersRoute.location),
            icon: const Icon(Icons.folder_outlined),
            tooltip: l10n.chatFolders,
          ),
          const NotificationBell(),
          if (showNewChat) ...[
            const SizedBox(width: AppSpacing.x1),
            IconButton.filledTonal(
              onPressed: () => context.push(CreateChatRoute.location),
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.newChat,
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBlock extends StatelessWidget {
  const _SearchBlock();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        ChatsListLayout.searchPaddingTop,
        AppSpacing.x4,
        ChatsListLayout.searchPaddingBottom,
      ),
      child: AppSearchPill(
        hint: l10n.chatsSearchHint,
        semanticLabel: l10n.searchEverything,
        onTap: () => context.push(ChatSearchRoute.location),
      ),
    );
  }
}

/// "Chats" — or, while the list cannot be trusted to be current, what is
/// being done about it: waiting for a network, connecting, updating.
///
/// Said in the title's own place rather than in a banner, because it is
/// about the whole list and lasts seconds. And said only once it has lasted:
/// the same [settleDelay] a chat's connection strip waits, so a reconnect
/// that succeeds at once never flickers the title.
class ChatsListTitle extends ConsumerStatefulWidget {
  const ChatsListTitle({super.key});

  /// How long the list has to be behind before the title says so.
  static const Duration settleDelay = ChatConnectionStrip.settleDelay;

  @override
  ConsumerState<ChatsListTitle> createState() => _ChatsListTitleState();
}

class _ChatsListTitleState extends ConsumerState<ChatsListTitle> {
  Timer? _settle;
  bool _settled = false;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  /// Starts, stops or leaves the countdown alone, to match the status.
  void _syncSettle({required bool calm}) {
    if (calm) {
      _settle?.cancel();
      _settle = null;
      if (_settled) {
        // Back to normal: the title returns on the next frame rather than
        // inside this build.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _settled = false);
        });
      }
      return;
    }

    if (_settled || _settle != null) return;

    _settle = Timer(ChatsListTitle.settleDelay, () {
      _settle = null;
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(chatsConnectionStatusProvider);
    _syncSettle(calm: status == null);

    final shown = _settled ? status : null;

    return AnimatedSwitcher(
      duration: AppMotion.base,
      switchInCurve: AppMotion.curve,
      switchOutCurve: AppMotion.reverseCurve,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.centerStart,
        children: [...previous, ?current],
      ),
      child: shown == null
          ? const _Heading(key: ValueKey<String>('heading'))
          : _StatusLine(key: ValueKey(shown), status: shown),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      header: true,
      child: Text(
        AppLocalizations.of(context).chats,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({super.key, required this.status});

  final ChatsConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final label = switch (status) {
      ChatsConnectionStatus.waitingForNetwork =>
        l10n.chatsStatusWaitingForNetwork,
      ChatsConnectionStatus.connecting => l10n.chatsStatusConnecting,
      ChatsConnectionStatus.updating => l10n.chatsStatusUpdating,
    };

    // A spinner means the app is at work and will be done by itself; waiting
    // on a network is not that, and neither is a reader who asked for less
    // motion — both get a still glyph.
    final spins = status.isWorking && !MediaQuery.disableAnimationsOf(context);

    final glyph = spins
        ? SizedBox.square(
            dimension: ChatsListLayout.statusGlyph,
            child: CircularProgressIndicator(
              strokeWidth: ChatsListLayout.statusStroke,
              color: scheme.primary,
            ),
          )
        : Icon(
            status.isWorking ? Icons.sync : Icons.cloud_off_outlined,
            size: ChatsListLayout.statusGlyph,
            color: scheme.onSurfaceVariant,
          );

    return Semantics(
      liveRegion: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          glyph,
          const SizedBox(width: ChatsListLayout.statusGap),
          // Shrunk rather than cut: in a 360 px list pane with three actions
          // beside it, "Waiting for network…" is wider than its slot in more
          // than one language, and half a status says nothing.
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                label,
                maxLines: 1,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
