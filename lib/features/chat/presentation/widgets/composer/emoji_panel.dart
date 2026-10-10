import 'dart:async';

import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/utils/emoji_catalog.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The emoji panel: what the keyboard turns into when the composer's smiley
/// is pressed.
///
/// A search field along the top, the catalog in sections down the middle,
/// and a strip of section tabs and a backspace along the bottom — the
/// backspace being there because the keyboard, with its own, is not.
///
/// "Recent" leads, and it is the app's one emoji history (the same one the
/// reaction bar is ordered by). It is read once, when the panel opens: a row
/// that reshuffled under the finger with every emoji tapped would make the
/// second tap land on the wrong one.
class EmojiPanel extends StatefulWidget {
  const EmojiPanel({
    super.key,
    required this.recent,
    required this.onEmoji,
    required this.onBackspace,
    this.compact = false,
    this.onSearchFocusChanged,
  });

  final List<String> recent;

  final ValueChanged<String> onEmoji;

  /// Deletes what is before the caret. Held, it repeats.
  final VoidCallback onBackspace;

  /// Down to the search field and one row of answers — the shape the panel
  /// takes while its search has the keyboard and sits on top of it.
  final bool compact;

  final ValueChanged<bool>? onSearchFocusChanged;

  @override
  State<EmojiPanel> createState() => _EmojiPanelState();
}

/// One run of the grid with its title: "Recent", or one of the catalog's
/// groups.
class _PanelSection {
  const _PanelSection({required this.group, required this.emojis});

  /// Null for "Recent".
  final EmojiGroup? group;
  final List<String> emojis;
}

class _EmojiPanelState extends State<EmojiPanel> {
  final _query = TextEditingController();
  final _searchFocus = FocusNode(debugLabel: 'EmojiPanel.search');
  final _scroll = ScrollController();

  late final List<_PanelSection> _sections = [
    if (widget.recent.isNotEmpty)
      _PanelSection(group: null, emojis: List.unmodifiable(widget.recent)),
    for (final section in EmojiCatalog.sections)
      _PanelSection(group: section.group, emojis: section.emojis),
  ];

  /// Where each section's title starts in the grid, for the current width.
  List<double> _offsets = const [];

  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(_onSearchFocus);
    _query.addListener(_onQuery);
    _scroll.addListener(_followScroll);
  }

  @override
  void dispose() {
    _searchFocus.removeListener(_onSearchFocus);
    _query.removeListener(_onQuery);
    _scroll.removeListener(_followScroll);
    _query.dispose();
    _searchFocus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearchFocus() =>
      widget.onSearchFocusChanged?.call(_searchFocus.hasFocus);

  void _onQuery() => setState(() {});

  bool get _isSearching => _query.text.trim().isNotEmpty;

  /// Lights the tab of whichever section the top of the grid is in.
  void _followScroll() {
    if (!_scroll.hasClients || _offsets.isEmpty) return;

    final top = _scroll.offset + 1;
    var index = 0;
    for (var i = 0; i < _offsets.length; i++) {
      if (_offsets[i] <= top) index = i;
    }
    if (index != _selected) setState(() => _selected = index);
  }

  void _jumpTo(int index) {
    if (_isSearching) _query.clear();
    setState(() => _selected = index);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || index >= _offsets.length) return;
      final target = _offsets[index].clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      unawaited(
        _scroll.animateTo(
          target,
          duration: AppMotion.base,
          curve: AppMotion.curve,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);

    final search = _SearchBar(controller: _query, focusNode: _searchFocus);

    if (widget.compact) {
      return Material(
        color: chatix.composerSurface,
        child: Column(
          children: [
            search,
            SizedBox(
              height: EmojiPanelSizes.cell + AppSpacing.x2,
              child: _ResultStrip(
                emojis: _isSearching
                    ? _searchResults(context)
                    : _sections.first.emojis,
                onEmoji: widget.onEmoji,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: chatix.composerSurface,
      child: Column(
        children: [
          search,
          Expanded(
            child: _isSearching
                ? _ResultGrid(
                    emojis: _searchResults(context),
                    onEmoji: widget.onEmoji,
                  )
                : _buildSections(context),
          ),
          _TabBar(
            groups: [for (final section in _sections) section.group],
            selected: _isSearching ? null : _selected,
            onSelected: _jumpTo,
            onBackspace: widget.onBackspace,
          ),
          // The home indicator's strip: the keyboard covered it, so the
          // panel in its place does too, and keeps its tabs above it.
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }

  List<String> _searchResults(BuildContext context) => EmojiCatalog.search(
    _query.text,
    languageCode: Localizations.localeOf(context).languageCode,
  );

  Widget _buildSections(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);

        // Every row is exactly one cell tall, so where each section starts
        // is arithmetic rather than a measurement — and a tab can scroll to
        // a section the grid has not built yet.
        final offsets = <double>[];
        var offset = 0.0;
        for (final section in _sections) {
          offsets.add(offset);
          final rows = (section.emojis.length / columns).ceil();
          offset +=
              EmojiPanelSizes.sectionHeaderHeight + rows * EmojiPanelSizes.cell;
        }
        _offsets = offsets;

        return CustomScrollView(
          controller: _scroll,
          slivers: [
            for (final section in _sections) ...[
              SliverToBoxAdapter(
                child: _SectionHeader(title: _titleOf(section.group, l10n)),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: EmojiPanelSizes.cell,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _EmojiCell(
                      emoji: section.emojis[index],
                      onTap: widget.onEmoji,
                    ),
                    childCount: section.emojis.length,
                  ),
                ),
              ),
            ],
            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppSpacing.x2),
            ),
          ],
        );
      },
    );
  }
}

/// How many cells fit across [width], less the grid's side padding.
int _columnsFor(double width) {
  final usable = width - AppSpacing.x2 * 2;
  final columns = (usable / EmojiPanelSizes.cell).floor();
  return columns < 1 ? 1 : columns;
}

String _titleOf(EmojiGroup? group, AppLocalizations l10n) => switch (group) {
  null => l10n.emojiGroupRecent,
  EmojiGroup.smileys => l10n.emojiGroupSmileys,
  EmojiGroup.animals => l10n.emojiGroupAnimals,
  EmojiGroup.food => l10n.emojiGroupFood,
  EmojiGroup.activities => l10n.emojiGroupActivities,
  EmojiGroup.travel => l10n.emojiGroupTravel,
  EmojiGroup.objects => l10n.emojiGroupObjects,
  EmojiGroup.symbols => l10n.emojiGroupSymbols,
  EmojiGroup.flags => l10n.emojiGroupFlags,
};

IconData _iconOf(EmojiGroup? group) => switch (group) {
  null => Icons.schedule_rounded,
  EmojiGroup.smileys => Icons.emoji_emotions_outlined,
  EmojiGroup.animals => Icons.pets_outlined,
  EmojiGroup.food => Icons.local_cafe_outlined,
  EmojiGroup.activities => Icons.sports_basketball_outlined,
  EmojiGroup.travel => Icons.directions_car_outlined,
  EmojiGroup.objects => Icons.lightbulb_outline_rounded,
  EmojiGroup.symbols => Icons.emoji_symbols_outlined,
  EmojiGroup.flags => Icons.flag_outlined,
};

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.focusNode});

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: EmojiPanelSizes.searchBarHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x3,
          AppSpacing.x2,
          AppSpacing.x3,
          0,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.x3),
              Icon(Icons.search_rounded, size: 20, color: scheme.outline),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: l10n.emojiSearchHint,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.outline,
                    ),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => controller.text.isEmpty
                    ? const SizedBox(width: AppSpacing.x3)
                    : IconButton(
                        tooltip: l10n.clear,
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        color: scheme.onSurfaceVariant,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: controller.clear,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: EmojiPanelSizes.sectionHeaderHeight,
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x4,
        AppSpacing.x1,
      ),
      child: Semantics(
        header: true,
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EmojiCell extends StatelessWidget {
  const _EmojiCell({required this.emoji, required this.onTap});

  final String emoji;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.md),
      onTap: () => onTap(emoji),
      child: Center(
        child: Text(
          emoji,
          // No family of its own: Manrope has no emoji, and the platform's
          // colour emoji font is what the fallback reaches.
          style: const TextStyle(fontSize: EmojiPanelSizes.glyph, height: 1.2),
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }
}

class _ResultGrid extends StatelessWidget {
  const _ResultGrid({required this.emojis, required this.onEmoji});

  final List<String> emojis;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    if (emojis.isEmpty) return const _NothingFound();

    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.x2),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columnsFor(constraints.maxWidth),
          mainAxisExtent: EmojiPanelSizes.cell,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) =>
            _EmojiCell(emoji: emojis[index], onTap: onEmoji),
      ),
    );
  }
}

class _ResultStrip extends StatelessWidget {
  const _ResultStrip({required this.emojis, required this.onEmoji});

  final List<String> emojis;
  final ValueChanged<String> onEmoji;

  @override
  Widget build(BuildContext context) {
    if (emojis.isEmpty) return const _NothingFound();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x1,
      ),
      itemExtent: EmojiPanelSizes.cell,
      itemCount: emojis.length,
      itemBuilder: (context, index) =>
          _EmojiCell(emoji: emojis[index], onTap: onEmoji),
    );
  }
}

class _NothingFound extends StatelessWidget {
  const _NothingFound();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        AppLocalizations.of(context).emojiSearchEmpty,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Section tabs, and the backspace the keyboard would otherwise have had.
class _TabBar extends StatelessWidget {
  const _TabBar({
    required this.groups,
    required this.selected,
    required this.onSelected,
    required this.onBackspace,
  });

  final List<EmojiGroup?> groups;
  final int? selected;
  final ValueChanged<int> onSelected;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SizedBox(
        height: EmojiPanelSizes.tabBarHeight,
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x2,
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < groups.length; i++)
                        _Tab(
                          icon: _iconOf(groups[i]),
                          label: _titleOf(groups[i], l10n),
                          isSelected: i == selected,
                          onTap: () => onSelected(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            _BackspaceKey(onBackspace: onBackspace),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  /// Narrow enough for the eight groups, "Recent" and the backspace to sit
  /// across a 360 px phone without scrolling.
  static const double _width = 36;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: _width / 2,
          child: SizedBox(
            width: _width,
            height: EmojiPanelSizes.tabBarHeight,
            child: Center(
              child: AnimatedContainer(
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                width: _width - AppSpacing.x1,
                height: _width - AppSpacing.x1,
                decoration: BoxDecoration(
                  color: isSelected
                      ? scheme.primary.withValues(alpha: 0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  icon,
                  size: EmojiPanelSizes.tabIconSize,
                  color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Backspace, which repeats while held — the way the keyboard's does.
class _BackspaceKey extends StatefulWidget {
  const _BackspaceKey({required this.onBackspace});

  final VoidCallback onBackspace;

  @override
  State<_BackspaceKey> createState() => _BackspaceKeyState();
}

class _BackspaceKeyState extends State<_BackspaceKey> {
  static const Duration _repeat = Duration(milliseconds: 90);

  Timer? _timer;

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(_repeat, (_) => widget.onBackspace());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Listener(
      onPointerUp: (_) => _stop(),
      onPointerCancel: (_) => _stop(),
      child: Tooltip(
        message: AppLocalizations.of(context).emojiBackspace,
        child: InkResponse(
          onTap: widget.onBackspace,
          onLongPress: _start,
          radius: EmojiPanelSizes.tabBarHeight / 2,
          child: SizedBox(
            width: EmojiPanelSizes.tabBarHeight + AppSpacing.x2,
            height: EmojiPanelSizes.tabBarHeight,
            child: Icon(
              Icons.backspace_outlined,
              size: EmojiPanelSizes.tabIconSize,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
