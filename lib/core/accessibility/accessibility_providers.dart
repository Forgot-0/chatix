import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/accessibility/accessibility_service.dart';

final accessibilityServiceProvider = Provider<AccessibilityService>((ref) {
  final service = FlutterAccessibilityService();

  service.init();

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

final accessibilitySettingsProvider =
    NotifierProvider<AccessibilitySettingsNotifier, AccessibilitySettings>(
      AccessibilitySettingsNotifier.new,
    );

class AccessibilitySettingsNotifier extends Notifier<AccessibilitySettings> {
  Function? _unregisterCallback;

  @override
  AccessibilitySettings build() {
    final service = ref.watch(accessibilityServiceProvider);

    _unregisterCallback = service.registerForSettingsChanges(
      _onSettingsChanged,
    );

    ref.onDispose(() {
      _unregisterCallback?.call();
    });

    return service.getCurrentSettings();
  }

  void _onSettingsChanged(AccessibilitySettings settings) {
    state = settings;
  }

  Future<void> announce(String message) async {
    final service = ref.read(accessibilityServiceProvider);
    await service.announce(message);
  }

  String getSemanticLabel(String key, [Map<String, String>? args]) {
    final service = ref.read(accessibilityServiceProvider);
    return service.getSemanticLabel(key, args);
  }
}

/// The platform's high-contrast switch, mirrored where the theme generator
/// can see it.
///
/// The generator runs above `MediaQuery` — a theme has to exist before there
/// is a `MaterialApp` to read one from — so the flag cannot simply be looked
/// up where it is needed. It is pushed here instead, by
/// [AccessibilityWrapper], and defaults to off: a harness that never mounts
/// the wrapper gets the ordinary theme rather than a half-applied one.
class SystemHighContrast extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool value) {
    if (state != value) state = value;
  }
}

final systemHighContrastProvider = NotifierProvider<SystemHighContrast, bool>(
  SystemHighContrast.new,
);

class AccessibilityWrapper extends ConsumerStatefulWidget {
  final Widget child;

  const AccessibilityWrapper({super.key, required this.child});

  @override
  ConsumerState<AccessibilityWrapper> createState() =>
      _AccessibilityWrapperState();
}

class _AccessibilityWrapperState extends ConsumerState<AccessibilityWrapper> {
  @override
  void initState() {
    super.initState();

    // The first reading. Deferred by a frame because a provider may not be
    // written to while one is being built, and this runs inside the build
    // that creates them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mirrorHighContrast(
        ref.read(accessibilitySettingsProvider).isHighContrastEnabled,
      );
    });
  }

  void _mirrorHighContrast(bool value) =>
      ref.read(systemHighContrastProvider.notifier).setEnabled(value);

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      accessibilitySettingsProvider.select((s) => s.isHighContrastEnabled),
      (_, next) => _mirrorHighContrast(next),
    );

    final settings = ref.watch(accessibilitySettingsProvider);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: settings.isReduceMotionEnabled,
        highContrast: settings.isHighContrastEnabled,
        textScaler: TextScaler.linear(settings.fontScale),
        boldText: settings.isBoldTextEnabled,
      ),
      child: widget.child,
    );
  }
}
