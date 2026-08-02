import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/core/router/app_routes.dart';

/// Step 1/2 of password reset — `POST /auth/password-resets/` (api-docs
/// §3.7). Rate limit: 3/hour.
class ResetPasswordRequestScreen extends ConsumerStatefulWidget {
  const ResetPasswordRequestScreen({super.key});

  @override
  ConsumerState<ResetPasswordRequestScreen> createState() =>
      _ResetPasswordRequestScreenState();
}

class _ResetPasswordRequestScreenState
    extends ConsumerState<ResetPasswordRequestScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final email = _formKey.currentState!.value['email'] as String;
    final result = await ref
        .read(requestPasswordResetUseCaseProvider)
        .execute(email: email);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.fold(
      (failure) => AppUtils.showSnackBar(
        context,
        message: failure is RateLimitFailure
            ? 'Too many attempts — please try again later.'
            : (failure.message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) {
        AppUtils.showSnackBar(
          context,
          message: 'Check your email for a reset code.',
        );
        context.push(ResetPasswordConfirmRoute.location);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the email on your account and we will send you a '
                  'code to reset your password.',
                ),
                const SizedBox(height: 24),
                FormBuilderTextField(
                  name: 'email',
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: AuthFieldValidators.email,
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
                      : const Text('Send Code'),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        context.push(ResetPasswordConfirmRoute.location),
                    child: const Text('I already have a code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
