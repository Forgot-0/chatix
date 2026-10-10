import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/providers/composer_keyboard_provider.dart';

/// What sits under the composer: the keyboard, the emoji panel, or nothing.
///
/// Owned by the chat screen and handed to both the composer (its button and
/// whether the field may raise the keyboard) and [ComposerPanelHost] (how
/// much room to keep under the composer).
class ComposerInputController extends ChangeNotifier {
  ComposerInputController({bool? softKeyboard})
    : softKeyboard = softKeyboard ?? _platformHasSoftKeyboard;

  /// Phones and tablets. A desktop has a physical keyboard and no on-screen
  /// one to swap the panel with, so there the panel simply opens under the
  /// composer and the field keeps typing.
  static bool get _platformHasSoftKeyboard =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  final bool softKeyboard;

  bool _emoji = false;
  bool _awaitingKeyboard = false;
  bool _searching = false;

  bool get isEmojiOpen => _emoji;

  /// The panel has been asked to give way to the keyboard, which is still
  /// on its way up. The room stays reserved until it arrives, or the
  /// composer would drop and then climb back.
  bool get isAwaitingKeyboard => _awaitingKeyboard;

  /// The panel's own search field has the focus — and, on a phone, the
  /// keyboard, which the panel then has to sit on top of.
  bool get isSearching => _searching;

  /// Whether the message field must not raise the keyboard: the panel is in
  /// its place. The field keeps its focus and its caret, so an emoji lands
  /// where the person was typing.
  bool get holdsKeyboard => softKeyboard && _emoji;

  /// Whether anything is drawn in the panel's place right now.
  bool get showsPanel => _emoji || _awaitingKeyboard;

  void openEmoji() {
    if (_emoji) return;
    _emoji = true;
    _awaitingKeyboard = false;
    notifyListeners();
  }

  /// Back to typing: on a phone the keyboard comes up where the panel was.
  void showKeyboard() {
    if (!_emoji) return;
    _emoji = false;
    _searching = false;
    _awaitingKeyboard = softKeyboard;
    notifyListeners();
  }

  void toggleEmoji() => _emoji ? showKeyboard() : openEmoji();

  /// Puts the panel away without bringing the keyboard back — back, a tap
  /// on the conversation.
  void close() {
    if (!_emoji && !_awaitingKeyboard) return;
    _emoji = false;
    _searching = false;
    _awaitingKeyboard = false;
    notifyListeners();
  }

  void keyboardArrived() {
    if (!_awaitingKeyboard) return;
    _awaitingKeyboard = false;
    notifyListeners();
  }

  void setSearching({required bool value}) {
    if (_searching == value || (value && !_emoji)) return;
    _searching = value;
    notifyListeners();
  }
}

/// How the room under the composer is shared out in one frame.
///
/// Everything is measured against the bottom edge the chat would have with
/// no keyboard at all. Two parties may be making room for the keyboard: the
/// layouts above this one ([consumed] — a shell scaffold resizing its body)
/// and this box itself ([localInset] — whatever keyboard is still over it).
/// Their sum is the keyboard's [overlap] with the chat.
///
/// The rule that keeps the conversation still: while the panel is showing,
/// the composer sits at `max(overlap, panel)` above that edge. Keyboard
/// leaving, panel arriving — the maximum does not move, so neither does the
/// composer, and the feed above it keeps its exact height.
@immutable
class ComposerPanelGeometry {
  const ComposerPanelGeometry({
    required this.slot,
    required this.panelHeight,
    required this.overlap,
    required this.compact,
  });

  /// Works out one frame.
  ///
  /// [panel] is the height the panel opens at (the remembered keyboard).
  /// While [searching] the panel sits on the keyboard instead of behind it,
  /// at least [EmojiPanelSizes.searchStripHeight] tall, and turns [compact]
  /// once that is all the room it has.
  factory ComposerPanelGeometry.resolve({
    required double consumed,
    required double localInset,
    required double panel,
    required bool showsPanel,
    required bool searching,
  }) {
    final overlap = consumed + localInset;

    if (!showsPanel) {
      return ComposerPanelGeometry(
        slot: localInset,
        panelHeight: 0,
        overlap: overlap,
        compact: false,
      );
    }

    final total = searching
        ? math.max(panel, overlap + EmojiPanelSizes.searchStripHeight)
        : math.max(overlap, panel);
    final laidOut = searching ? total - overlap : panel;

    return ComposerPanelGeometry(
      slot: math.max(0.0, total - consumed),
      panelHeight: laidOut,
      overlap: overlap,
      compact: searching && laidOut < panel - 1,
    );
  }

  /// The box under the composer, in this layout's own pixels.
  final double slot;

  /// What the panel is laid out at. Taller than [slot] while the keyboard
  /// is still crossing it — the part under the keyboard is clipped.
  final double panelHeight;

  /// How far the keyboard reaches into the chat.
  final double overlap;

  /// The panel is down to its search field and a row of answers.
  final bool compact;
}

/// The chat's body above, and the keyboard's or the emoji panel's room
/// below — never both stacked, and never a jump between them.
///
/// The chat screen turns off its scaffold's own keyboard avoidance and
/// leaves it to this: a scaffold can only shrink the body by the keyboard,
/// and the whole point here is to keep the body the same height while the
/// keyboard and the panel trade places.
class ComposerPanelHost extends ConsumerStatefulWidget {
  const ComposerPanelHost({
    super.key,
    required this.controller,
    required this.panelBuilder,
    required this.child,
  });

  final ComposerInputController controller;

  /// Builds the panel at the height it is given; `compact` is the search
  /// strip that rides on top of the keyboard.
  final Widget Function(BuildContext context, double height, bool compact)
  panelBuilder;

  /// The conversation and the composer.
  final Widget child;

  @override
  ConsumerState<ComposerPanelHost> createState() => _ComposerPanelHostState();
}

class _ComposerPanelHostState extends ConsumerState<ComposerPanelHost>
    with WidgetsBindingObserver {
  /// How long the keyboard gets to arrive after the panel steps aside. A
  /// hardware keyboard, or a phone that decides not to show one, never
  /// sends it — and the room cannot stay reserved forever.
  static const Duration _keyboardDeadline = Duration(milliseconds: 700);

  /// How long the window has to stop changing before the keyboard counts as
  /// settled and its height is worth remembering.
  static const Duration _settleDelay = Duration(milliseconds: 200);

  /// This box's height and width with no keyboard anywhere: what "consumed
  /// by the layouts above" is measured from.
  double? _restHeight;
  double? _restWidth;

  /// The overlap of the last layout, for the settle timer to read.
  double _overlap = 0;

  Timer? _settle;
  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(ComposerPanelHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    _settle?.cancel();
    _deadline?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Rebuild on every step of the keyboard's animation: a scaffold above
    // that already removed the inset would otherwise hide the change.
    if (mounted) setState(() {});

    _settle?.cancel();
    _settle = Timer(_settleDelay, _rememberKeyboard);
  }

  void _onControllerChanged() {
    if (!mounted) return;

    _deadline?.cancel();
    if (widget.controller.isAwaitingKeyboard) {
      _deadline = Timer(_keyboardDeadline, widget.controller.keyboardArrived);
    }
    setState(() {});
  }

  /// The keyboard as the window has it, before any layout above removed it.
  double _windowInset() {
    final view = View.maybeOf(context);
    if (view == null) return MediaQuery.viewInsetsOf(context).bottom;
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  void _rememberKeyboard() {
    if (!mounted || _windowInset() <= 0) return;
    ref.read(composerKeyboardHeightProvider.notifier).remember(_overlap);
  }

  @override
  Widget build(BuildContext context) {
    final remembered = ref.watch(composerKeyboardHeightProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final width = constraints.maxWidth;
        final window = _windowInset();
        final local = MediaQuery.viewInsetsOf(context).bottom;

        if (_restWidth != width) {
          // A new width is a new window — rotated, resized. Whatever the
          // window's keyboard is not over this box has been taken off it
          // further up.
          _restWidth = width;
          _restHeight = height + math.max(0.0, window - local);
        } else if (window <= 0) {
          _restHeight = height;
        }

        final consumed = math.max(0.0, (_restHeight ?? height) - height);
        final ceiling = math.max(
          EmojiPanelSizes.minHeight,
          (_restHeight ?? height) * EmojiPanelSizes.maxHeightFactor,
        );
        final panel = (remembered ?? EmojiPanelSizes.defaultHeight)
            .clamp(EmojiPanelSizes.minHeight, ceiling)
            .toDouble();

        final controller = widget.controller;
        final geometry = ComposerPanelGeometry.resolve(
          consumed: consumed,
          localInset: local,
          panel: panel,
          showsPanel: controller.showsPanel,
          searching: controller.isSearching,
        );
        _overlap = geometry.overlap;

        if (controller.isAwaitingKeyboard && geometry.overlap >= panel - 1) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller.keyboardArrived(),
          );
        }

        return Column(
          children: [
            Expanded(
              // The panel is drawn to the very bottom and keeps the home
              // indicator's strip clear itself; the composer above it no
              // longer stands on that edge.
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: controller.showsPanel,
                child: widget.child,
              ),
            ),
            SizedBox(
              height: geometry.slot,
              child: controller.showsPanel
                  ? ClipRect(
                      child: OverflowBox(
                        alignment: Alignment.topCenter,
                        minHeight: geometry.panelHeight,
                        maxHeight: geometry.panelHeight,
                        child: widget.panelBuilder(
                          context,
                          geometry.panelHeight,
                          geometry.compact,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        );
      },
    );
  }
}
