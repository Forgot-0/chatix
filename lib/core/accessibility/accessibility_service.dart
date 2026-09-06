import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class AccessibilityService {
  Future<bool> isScreenReaderActive();

  AccessibilitySettings getCurrentSettings();

  Future<void> announce(String message);

  Future<void> init();

  Future<void> dispose();

  Function registerForSettingsChanges(Function(AccessibilitySettings) callback);

  String getSemanticLabel(String key, Map<String, String>? args);
}

class AccessibilitySettings {
  final bool isScreenReaderActive;

  final bool isHighContrastEnabled;

  final bool isBoldTextEnabled;

  final bool isReduceMotionEnabled;

  final double fontScale;

  const AccessibilitySettings({
    this.isScreenReaderActive = false,
    this.isHighContrastEnabled = false,
    this.isBoldTextEnabled = false,
    this.isReduceMotionEnabled = false,
    this.fontScale = 1.0,
  });

  AccessibilitySettings copyWith({
    bool? isScreenReaderActive,
    bool? isHighContrastEnabled,
    bool? isBoldTextEnabled,
    bool? isReduceMotionEnabled,
    double? fontScale,
  }) {
    return AccessibilitySettings(
      isScreenReaderActive: isScreenReaderActive ?? this.isScreenReaderActive,
      isHighContrastEnabled:
          isHighContrastEnabled ?? this.isHighContrastEnabled,
      isBoldTextEnabled: isBoldTextEnabled ?? this.isBoldTextEnabled,
      isReduceMotionEnabled:
          isReduceMotionEnabled ?? this.isReduceMotionEnabled,
      fontScale: fontScale ?? this.fontScale,
    );
  }
}

class FlutterAccessibilityService implements AccessibilityService {
  final FlutterTts _flutterTts = FlutterTts();
  AccessibilitySettings _currentSettings = const AccessibilitySettings();
  final List<Function(AccessibilitySettings)> _listeners = [];

  @override
  Future<void> init() async {
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);

    SemanticsBinding.instance.addSemanticsEnabledListener(_updateSettings);

    _updateSettings();

    debugPrint('📱 Accessibility service initialized');
  }

  void _updateSettings() {
    final mediaQueryData = MediaQueryData.fromView(
      WidgetsBinding.instance.platformDispatcher.views.first,
    );

    _currentSettings = AccessibilitySettings(
      isScreenReaderActive: SemanticsBinding.instance.semanticsEnabled,
      isHighContrastEnabled: mediaQueryData.highContrast,
      isBoldTextEnabled: mediaQueryData.boldText,
      isReduceMotionEnabled: mediaQueryData.disableAnimations,
      fontScale: mediaQueryData.textScaler.scale(1.0),
    );

    for (final listener in _listeners) {
      listener(_currentSettings);
    }
  }

  @override
  Future<bool> isScreenReaderActive() async {
    return SemanticsBinding.instance.semanticsEnabled;
  }

  @override
  AccessibilitySettings getCurrentSettings() {
    return _currentSettings;
  }

  @override
  Future<void> announce(String message) async {
    if (await isScreenReaderActive()) {
      // ignore: deprecated_member_use
      SemanticsService.announce(message, TextDirection.ltr);

      try {
        await _flutterTts.speak(message);
      } catch (e) {
        debugPrint('📱 Error speaking message: $e');
      }
    }
  }

  @override
  Future<void> dispose() async {
    SemanticsBinding.instance.removeSemanticsEnabledListener(_updateSettings);
    await _flutterTts.stop();
  }

  @override
  Function registerForSettingsChanges(
    Function(AccessibilitySettings) callback,
  ) {
    _listeners.add(callback);

    return () => _listeners.remove(callback);
  }

  @override
  String getSemanticLabel(String key, Map<String, String>? args) {
    return key;
  }
}
