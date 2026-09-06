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

class AccessibilityWrapper extends ConsumerWidget {
  final Widget child;

  const AccessibilityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(accessibilitySettingsProvider);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: settings.isReduceMotionEnabled,
        highContrast: settings.isHighContrastEnabled,
        textScaler: TextScaler.linear(settings.fontScale),
        boldText: settings.isBoldTextEnabled,
      ),
      child: child,
    );
  }
}
