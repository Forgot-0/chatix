import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/theme_providers.dart';

/// The physical vocabulary, one level below the semantic calls.
///
/// Four strengths, because a phone only has a handful of distinguishable
/// taps and pretending otherwise produces a buzz nobody can read.
enum HapticStrength {
  /// A tick. State picked, threshold crossed, item selected.
  selection,

  /// A tap. Something small happened because you did something.
  light,

  /// A knock. Something started, or a menu took over.
  medium,

  /// A thud. Something ended, locked, or went wrong.
  heavy,
}

/// Where a haptic actually goes. A seam, so tests can watch without a plugin.
abstract interface class HapticDriver {
  void impact(HapticStrength strength);
}

/// The real one: the platform channel.
///
/// Both Android and iOS gate `HapticFeedback` on the device's own
/// touch-feedback setting, so a phone with vibration turned off stays silent
/// without the app checking anything — which is just as well, since neither
/// platform exposes that switch to Flutter for reading.
class PlatformHapticDriver implements HapticDriver {
  const PlatformHapticDriver();

  @override
  void impact(HapticStrength strength) {
    switch (strength) {
      case HapticStrength.selection:
        HapticFeedback.selectionClick();
      case HapticStrength.light:
        HapticFeedback.lightImpact();
      case HapticStrength.medium:
        HapticFeedback.mediumImpact();
      case HapticStrength.heavy:
        HapticFeedback.heavyImpact();
    }
  }
}

/// Every vibration the app makes, named after what happened rather than how
/// hard it buzzes.
///
/// One entry point for three reasons. It is the only way the global switch in
/// appearance settings can actually be global — a `HapticFeedback` call
/// scattered in a widget answers to nobody. It keeps the *vocabulary*
/// consistent: sending a message feels the same everywhere because there is
/// one definition of what sending feels like, not eleven call sites that each
/// picked a strength. And it is the only way to tell, by reading one file,
/// what the app feels like — which is the thing a design review of haptics
/// actually needs.
///
/// Static rather than a provider because the call sites are not all
/// `Consumer`s — a gesture recogniser inside a plain widget, a snackbar
/// helper with nothing but a `BuildContext` — and threading a ref through
/// them would buy nothing: this is a write-only side effect with no state to
/// read back. [HapticsSettingsSync] mirrors the setting in, the same way
/// `AccessibilityWrapper` mirrors the platform's accessibility flags.
///
/// The rule for adding one: a haptic confirms something the user *did* that
/// they might not otherwise feel. Never notify with one, never decorate with
/// one, and never fire one per frame — a gesture that crosses a threshold
/// ticks once, on the way in.
abstract final class AppHaptics {
  static bool _enabled = true;

  /// Swappable for tests. Const platform driver in the app.
  @visibleForTesting
  static HapticDriver driver = const PlatformHapticDriver();

  /// Whether the app is allowed to vibrate at all.
  ///
  /// The user's switch, not the system's — the system's is enforced below us
  /// by the platform.
  static bool get enabled => _enabled;

  static void setEnabled(bool value) => _enabled = value;

  /// Restores the defaults. For tests, which share a process.
  @visibleForTesting
  static void reset() {
    _enabled = true;
    driver = const PlatformHapticDriver();
  }

  // ── What the app can feel like ────────────────────────────────────────

  /// A message left the composer. The lightest confirmation there is: it
  /// happens dozens of times an hour and must never feel like an event.
  static void messageSent() => _fire(HapticStrength.light);

  /// A reaction went on or came off a message.
  static void reactionToggled() => _fire(HapticStrength.selection);

  /// A swipe crossed the point where letting go would do something — or came
  /// back below it. Fired on crossing, never per frame.
  static void gestureThreshold() => _fire(HapticStrength.selection);

  /// A recording started: the microphone is live from this instant, which is
  /// worth a knock rather than a tick.
  static void recordingStarted() => _fire(HapticStrength.medium);

  /// A recording was locked hands-free: the thumb can leave the button.
  static void recordingLocked() => _fire(HapticStrength.medium);

  /// The recorder took over — the length cap is close, or has stopped the
  /// take. The heaviest thing here, because it is the only one that happens
  /// without anybody asking for it.
  static void recordingLimit() => _fire(HapticStrength.heavy);

  /// A recording was thrown away — by the cancel slide, or by letting go
  /// past it. Deliberately the gentlest of the four: a discard should not
  /// feel like a failure.
  static void recordingCancelled() => _fire(HapticStrength.light);

  /// A long press took: the menu is opening, the selection has started.
  static void longPress() => _fire(HapticStrength.medium);

  /// A discrete choice landed — a tab, a segment, an option in a sheet.
  static void selection() => _fire(HapticStrength.selection);

  /// Something failed, or was refused. The one haptic the app fires for
  /// news the user did not ask for, and the reason it is allowed is that it
  /// always follows an action of theirs that did not work.
  static void error() => _fire(HapticStrength.heavy);

  static void _fire(HapticStrength strength) {
    if (!_enabled) return;
    driver.impact(strength);
  }
}

/// Mirrors the user's haptics switch into [AppHaptics].
///
/// The same shape as `AccessibilityWrapper`: the setting lives in a provider,
/// the thing that needs it is not a widget and has no ref, so one widget
/// mounted near the root pushes the value across whenever it changes. Draws
/// nothing of its own.
class HapticsSettingsSync extends ConsumerWidget {
  const HapticsSettingsSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AppHaptics.setEnabled(ref.watch(hapticsEnabledProvider));
    return child;
  }
}
