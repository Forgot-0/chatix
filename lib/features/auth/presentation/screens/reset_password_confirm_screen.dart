import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/features/auth/presentation/utils/auth_form_errors.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_password_field.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Step two of the reset: the code from the letter and the new password
/// (`POST /auth/password-resets/confirm/`, api-docs §3.7).
///
/// The new password is held to the registration rules, so it gets the same
/// checklist. A wrong or expired code is said under the code, a mismatch
/// under the repeat; anything else goes above the form.
class ResetPasswordConfirmScreen extends ConsumerStatefulWidget {
  const ResetPasswordConfirmScreen({super.key});

  @override
  ConsumerState<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends ConsumerState<ResetPasswordConfirmScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _passwordFocus = FocusNode();
  final _repeatFocus = FocusNode();
  final _errors = AuthFormErrors(const {
    'token',
    'password',
    'password_repeat',
  });

  bool _isSubmitting = false;
  AuthErrorInfo? _error;

  @override
  void dispose() {
    _passwordFocus.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  String _valueOf(String field) =>
      (_formKey.currentState?.fields[field]?.value as String?) ?? '';

  String _currentPassword() => _valueOf('password');

  /// As on registration: the repeat is re-checked as the password changes,
  /// but only once there is one.
  void _recheckRepeat() {
    final repeat = _formKey.currentState?.fields['password_repeat'];
    if (repeat == null || _valueOf('password_repeat').isEmpty) return;
    repeat.validate(focusOnInvalid: false);
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    final values = _formKey.currentState!.value;
    final sent = {
      for (final field in _errors.fields) field: values[field] as String,
    };
    _errors.remember(sent);
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await ref
        .read(confirmPasswordResetUseCaseProvider)
        .execute(
          token: sent['token']!.trim(),
          password: sent['password']!,
          passwordRepeat: sent['password_repeat']!,
        );

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    result.fold(
      (failure) => setState(() {
        _isSubmitting = false;
        _error = describeAuthFailure(failure, l10n);
      }),
      (_) {
        setState(() => _isSubmitting = false);
        // The new password is one worth offering to save.
        TextInput.finishAutofillContext();
        AppUtils.showSnackBar(context, message: l10n.passwordUpdated);
        context.go(LoginRoute.location);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AuthScaffold(
      header: const AppIllustration(
        kind: AppIllustrationKind.locked,
        size: AuthLayout.illustrationSize,
      ),
      title: l10n.setNewPassword,
      subtitle: l10n.resetPasswordConfirmIntro,
      children: [
        AuthErrorBanner(error: _errors.inBanner(_error)),
        AutofillGroup(
          child: FormBuilder(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormBuilderTextField(
                  name: 'token',
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: l10n.resetCode,
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    errorText: _errors.under(_error, 'token', _valueOf),
                  ),
                  validator: AuthFieldValidators.required(l10n),
                ),
                const SizedBox(height: AppSpacing.x4),
                AuthPasswordField(
                  name: 'password',
                  focusNode: _passwordFocus,
                  labelText: l10n.newPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  isNewPassword: true,
                  onSubmitted: _repeatFocus.requestFocus,
                  onChanged: (_) => _recheckRepeat(),
                  validator: AuthFieldValidators.password(l10n),
                ),
                const SizedBox(height: AppSpacing.x4),
                AuthPasswordField(
                  name: 'password_repeat',
                  focusNode: _repeatFocus,
                  labelText: l10n.confirmNewPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _errors.under(_error, 'password_repeat', _valueOf),
                  onSubmitted: _submit,
                  validator: AuthFieldValidators.passwordRepeat(
                    l10n,
                    _currentPassword,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
        AuthSubmitButton(
          label: l10n.resetPasswordSave,
          isBusy: _isSubmitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
