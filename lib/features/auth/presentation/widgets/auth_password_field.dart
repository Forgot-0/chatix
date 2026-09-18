import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';

import 'package:chatix/features/auth/presentation/widgets/password_strength_meter.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A password field with the three things every one of them needs: a reveal
/// toggle, autofill wired to the platform's password manager, and a keyboard
/// action that moves on instead of dead-ending.
///
/// The strength meter is opt-in — it belongs under a password being chosen,
/// not under one being recalled.
class AuthPasswordField extends StatefulWidget {
  const AuthPasswordField({
    required this.name,
    required this.labelText,
    this.hintText,
    this.validator,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.showStrengthMeter = false,
    super.key,
  });

  final String name;
  final String labelText;
  final String? hintText;
  final String? Function(String?)? validator;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final FocusNode? focusNode;
  final VoidCallback? onSubmitted;
  final ValueChanged<String?>? onChanged;
  final bool showStrengthMeter;

  @override
  State<AuthPasswordField> createState() => _AuthPasswordFieldState();
}

class _AuthPasswordFieldState extends State<AuthPasswordField> {
  bool _obscured = true;
  String _value = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormBuilderTextField(
          name: widget.name,
          focusNode: widget.focusNode,
          obscureText: _obscured,
          autofillHints: widget.autofillHints,
          textInputAction: widget.textInputAction,
          onSubmitted: (_) => widget.onSubmitted?.call(),
          onChanged: (value) {
            if (widget.showStrengthMeter) {
              setState(() => _value = value ?? '');
            }
            widget.onChanged?.call(value);
          },
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _obscured ? l10n.passwordShow : l10n.passwordHide,
              icon: Icon(
                _obscured ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: () => setState(() => _obscured = !_obscured),
            ),
          ),
          validator: widget.validator,
        ),
        if (widget.showStrengthMeter) PasswordStrengthMeter(password: _value),
      ],
    );
  }
}
