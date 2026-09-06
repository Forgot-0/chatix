import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/accessibility/accessibility_providers.dart';
import 'package:chatix/core/constants/app_constants.dart';

extension AccessibilityWidgetExtensions on Widget {
  Widget withMinimumTouchTargetSize() {
    return SizedBox(
      width: AppConstants.accessibilityTouchTargetMinSize,
      height: AppConstants.accessibilityTouchTargetMinSize,
      child: Center(child: this),
    );
  }

  Widget withSemanticLabel(String label) {
    return Semantics(label: label, child: this);
  }

  Widget excludeFromSemantics() {
    return ExcludeSemantics(child: this);
  }

  Widget withIncreasedTouchTarget({double minSize = 48.0}) {
    return MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minSize, minHeight: minSize),
        child: this,
      ),
    );
  }

  Widget withAccessibleTooltip(String message) {
    return Tooltip(
      message: message,
      showDuration: AppConstants.accessibilityTooltipDuration,
      child: this,
    );
  }

  Widget conditionallyAccessible(
    bool isAccessible, {
    required String accessibleLabel,
  }) {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(accessibilitySettingsProvider);

        if (settings.isScreenReaderActive && isAccessible) {
          return Semantics(
            label: accessibleLabel,
            excludeSemantics: false,
            child: this,
          );
        }

        return this;
      },
    );
  }
}

class AccessibleButton extends ConsumerWidget {
  final Widget child;

  final String semanticLabel;

  final VoidCallback? onPressed;

  const AccessibleButton({
    super.key,
    required this.child,
    required this.semanticLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: semanticLabel,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: AppConstants.accessibilityTouchTargetMinSize,
            minHeight: AppConstants.accessibilityTouchTargetMinSize,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class AccessibleTextField extends StatelessWidget {
  final TextEditingController? controller;

  final String semanticLabel;

  final String? hintText;

  final String? errorText;

  final void Function(String)? onChanged;

  final bool obscureText;

  const AccessibleTextField({
    super.key,
    this.controller,
    required this.semanticLabel,
    this.hintText,
    this.errorText,
    this.onChanged,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: semanticLabel,
      hint: hintText,
      value: controller?.text,
      enabled: true,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: semanticLabel,
          hintText: hintText,
          errorText: errorText,
        ),
      ),
    );
  }
}

class AccessibleSwitch extends StatelessWidget {
  final String semanticLabel;

  final bool value;

  final ValueChanged<bool> onChanged;

  const AccessibleSwitch({
    super.key,
    required this.semanticLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      toggled: value,
      child: Switch(value: value, onChanged: onChanged),
    );
  }
}
