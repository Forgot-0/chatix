import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// What the app can be driven with besides a finger.
///
/// The desktop layer — shortcuts, Enter to send, right clicks, hover
/// buttons, pasting and dropping files — switches on here and nowhere else,
/// so a phone keeps behaving exactly like a phone. Read on every use rather
/// than cached, which is what lets a test flip the platform with
/// `debugDefaultTargetPlatformOverride`.
abstract final class DesktopInput {
  /// macOS, Windows and Linux: a physical keyboard is a given there, and so
  /// is something to point with.
  static bool get isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => true,
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => false,
  };

  /// Whether there is a pointer that can hover: always on a desktop, and on
  /// a tablet once a mouse or a trackpad is connected to it.
  static bool get hasPointer =>
      isDesktop || RendererBinding.instance.mouseTracker.mouseIsConnected;

  /// Cmd on Apple keyboards, Ctrl everywhere else — the modifier the app's
  /// own shortcuts hang off.
  static bool get usesCommandKey =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// [key] with the platform's primary modifier: Ctrl+K on Windows and
  /// Linux, Cmd+K on a Mac.
  static SingleActivator primary(
    LogicalKeyboardKey key, {
    bool shift = false,
  }) => SingleActivator(
    key,
    control: !usesCommandKey,
    meta: usesCommandKey,
    shift: shift,
  );

  /// Whether the primary modifier is held right now.
  static bool get isPrimaryPressed => usesCommandKey
      ? HardwareKeyboard.instance.isMetaPressed
      : HardwareKeyboard.instance.isControlPressed;
}

/// A hand over whatever [child] does on a click, where the pointer can
/// hover.
///
/// For tap targets built from a bare `GestureDetector`, which, unlike an
/// `InkWell`, says nothing to the mouse about being clickable. A null
/// [onTap]-equivalent is passed as [enabled] false: the arrow stays.
class ClickCursor extends StatelessWidget {
  const ClickCursor({super.key, this.enabled = true, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return MouseRegion(cursor: SystemMouseCursors.click, child: child);
  }
}
