import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

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
      (_) => AppUtils.showSnackBar(
        context,
        message: AppLocalizations.of(context).emailVerified,
      ),
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
        message: failure is RateLimitFailure
            ? 'Too many attempts — please try again later.'
            : friendlyFailureMessage(failure),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) => AppUtils.showSnackBar(
        context,
        message: AppLocalizations.of(context).verificationSent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).verifyEmailTitle),
      ),
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
              Text(AppLocalizations.of(context).verifyEmailHint),
              const SizedBox(height: 16),
              FormBuilder(
                key: _tokenFormKey,
                child: FormBuilderTextField(
                  name: 'token',
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).verificationToken,
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
                    : Text(AppLocalizations.of(context).verify),
              ),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                "Didn't get an email?",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context).resendLimitHint),
              const SizedBox(height: 16),
              FormBuilder(
                key: _resendFormKey,
                child: FormBuilderTextField(
                  name: 'email',
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).email,
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
                    : Text(AppLocalizations.of(context).resendVerification),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
