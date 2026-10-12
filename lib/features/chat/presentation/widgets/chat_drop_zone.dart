import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/core/ui/motion/motion.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A chat that takes files dragged onto it from the desktop.
///
/// While they hover, a plate over the conversation says where they will go;
/// once they land, [onDropped] gets their paths and the chat takes it from
/// there — the same preview a pick from the paperclip opens. A phone has
/// nothing to drag from, so there this is only [child].
class ChatDropZone extends StatefulWidget {
  const ChatDropZone({
    super.key,
    required this.onDropped,
    this.enabled = true,
    required this.child,
  });

  /// Paths of the files that were let go of over the chat.
  final ValueChanged<List<String>> onDropped;

  /// Off where the chat cannot take files: the composer is locked, or an
  /// edit is in it (`PATCH` carries only text, api-docs §5.4).
  final bool enabled;

  final Widget child;

  @override
  State<ChatDropZone> createState() => _ChatDropZoneState();
}

class _ChatDropZoneState extends State<ChatDropZone> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering == value || !mounted) return;
    setState(() => _hovering = value);
  }

  void _onDone(DropDoneDetails details) {
    _setHovering(false);

    final paths = [
      for (final file in details.files)
        if (file.path.isNotEmpty) file.path,
    ];
    if (paths.isNotEmpty) widget.onDropped(paths);
  }

  @override
  Widget build(BuildContext context) {
    if (!DesktopInput.isDesktop) return widget.child;

    // Every drop target in the window hears a drag, covered or not, so a
    // chat with another page over it — the preview it opened, the viewer —
    // stops listening until it is the one on screen again. Its subtree's
    // tickers say exactly that.
    final listening = widget.enabled && TickerMode.valuesOf(context).enabled;

    return DropTarget(
      enable: listening,
      onDragEntered: (_) => _setHovering(true),
      onDragExited: (_) => _setHovering(false),
      onDragDone: _onDone,
      child: Stack(
        // The chat is laid out exactly as it would be without the plate.
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hovering && listening ? 1 : 0,
                duration: context.motion(AppMotion.fast),
                curve: AppMotion.curve,
                child: const ChatDropPlate(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "drop to send" plate: the conversation washed out under it, an
/// outlined field in the accent, and what letting go will do.
class ChatDropPlate extends StatelessWidget {
  const ChatDropPlate({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return ColoredBox(
      color: scheme.surface.withValues(alpha: 0.86),
      child: Padding(
        padding: const EdgeInsets.all(DesktopSizes.dropInset),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(
              color: scheme.primary,
              width: DesktopSizes.dropBorder,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.file_upload_outlined,
                    size: DesktopSizes.dropIcon,
                    color: scheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    l10n.chatDropTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    l10n.chatDropHint,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
