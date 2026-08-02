import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/core/router/app_routes.dart';

/// Step 2/2 of password reset — `POST /auth/password-resets/confirm/`
/// (api-docs §3.7): token from the email + a new password (same complexity
/// rule as registration).
class ResetPasswordConfirmScreen extends ConsumerStatefulWidget {
  const ResetPasswordConfirmScreen({super.key});

  @override
  ConsumerState<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends ConsumerState<ResetPasswordConfirmScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  String _currentPassword() =>
      (_formKey.currentState?.fields['password']?.value as String?) ?? '';

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final values = _formKey.currentState!.value;
    final result = await ref.read(confirmPasswordResetUseCaseProvider).execute(
      token: values['token'] as String,
      password: values['password'] as String,
      passwordRepeat: values['password_repeat'] as String,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) => AppUtils.showSnackBar(
        context,
        message: failure.message,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) {
        AppUtils.showSnackBar(
          context,
          message: 'Password updated — please log in.',
        );
        context.go(LoginRoute.location);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set New Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Enter the code from your email and a new password.'),
                const SizedBox(height: 24),
                FormBuilderTextField(
                  name: 'token',
                  decoration: const InputDecoration(
                    labelText: 'Reset code',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  validator: AuthFieldValidators.required,
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'password',
                  obscureText: !_isPasswordVisible,
                  onChanged: (_) =>
                      _formKey.currentState?.fields['password_repeat']?.validate(),
                  decoration: InputDecoration(
                    labelText: 'New password',
                    hintText: '8+ chars, upper/lower/digit/special',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                  ),
                  validator: AuthFieldValidators.password,
                ),
                const SizedBox(height: 16),
                FormBuilderTextField(
                  name: 'password_repeat',
                  obscureText: !_isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Confirm new password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () => setState(
                        () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
                      ),
                    ),
                  ),
                  validator: AuthFieldValidators.passwordRepeat(_currentPassword),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
