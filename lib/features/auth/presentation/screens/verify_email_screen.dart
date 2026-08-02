import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/core/error/failure_messages.dart';

/// api-docs §3.6. Two independent actions on one screen:
///  - confirm a token the person already has (from the email they got), and
///  - (re)send that email if they don't have a token yet / it expired.
///
/// TODO(deep-link): if the verification email's link is opened directly by
/// the app (universal/app link with `?token=...`), this screen should read
/// that query param and pre-fill/auto-submit the token field. Not wired up
/// yet — out of scope for this pass, see also the OAuth callback TODO in
/// `oauth_buttons.dart` for the same underlying deep-link-handling gap.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _tokenFormKey = GlobalKey<FormBuilderState>();
  final _resendFormKey = GlobalKey<FormBuilderState>();

  bool _isConfirming = false;
  bool _isResending = false;

  Future<void> _confirm() async {
    final isValid = _tokenFormKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _isConfirming = true);

    final token = _tokenFormKey.currentState!.value['token'] as String;
    final result = await ref
        .read(confirmEmailVerificationUseCaseProvider)
        .execute(token: token);

    if (!mounted) return;
    setState(() => _isConfirming = false);

    result.fold(
      (failure) => AppUtils.showSnackBar(
        context,
        message: friendlyFailureMessage(failure),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) => AppUtils.showSnackBar(context, message: 'Email verified!'),
    );
  }

  Future<void> _resend() async {
    final isValid = _resendFormKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    setState(() => _isResending = true);

    final email = _resendFormKey.currentState!.value['email'] as String;
    final result = await ref
        .read(requestEmailVerificationUseCaseProvider)
        .execute(email: email);

    if (!mounted) return;
    setState(() => _isResending = false);

    result.fold(
      (failure) => AppUtils.showSnackBar(
        context,
        // api-docs §3.6: 3 requests/hour — surface the rate limit clearly
        // rather than a generic error.
        message: failure is RateLimitFailure
            ? 'Too many attempts — please try again later.'
            : friendlyFailureMessage(failure),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) => AppUtils.showSnackBar(
        context,
        message: 'Verification email sent — check your inbox.',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Enter verification code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Paste the token from the email we sent you.'),
              const SizedBox(height: 16),
              FormBuilder(
                key: _tokenFormKey,
                child: FormBuilderTextField(
                  name: 'token',
                  decoration: const InputDecoration(
                    labelText: 'Verification token',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                  ),
                  validator: AuthFieldValidators.required,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isConfirming ? null : _confirm,
                child: _isConfirming
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Verify'),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Didn't get an email?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'We can resend it — up to 3 times per hour.',
              ),
              const SizedBox(height: 16),
              FormBuilder(
                key: _resendFormKey,
                child: FormBuilderTextField(
                  name: 'email',
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: AuthFieldValidators.email,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _isResending ? null : _resend,
                child: _isResending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Resend verification email'),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
