import 'package:flutter/material.dart';
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
import 'package:chatix/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Step one of the reset: the address the code goes to
/// (`POST /auth/password-resets/`, api-docs §3.7).
///
/// An address with no account behind it (`NOT_FOUND_USER`) is said under the
/// field; a rate limit or a dead network stays above the form, where a
/// snackbar would have left before it was read.
class ResetPasswordRequestScreen extends ConsumerStatefulWidget {
  const ResetPasswordRequestScreen({super.key});

  @override
  ConsumerState<ResetPasswordRequestScreen> createState() =>
      _ResetPasswordRequestScreenState();
}

class _ResetPasswordRequestScreenState
    extends ConsumerState<ResetPasswordRequestScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _errors = AuthFormErrors(const {'email'});

  bool _isSubmitting = false;
  AuthErrorInfo? _error;

  String _valueOf(String field) =>
      (_formKey.currentState?.fields[field]?.value as String?) ?? '';

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();
    final email = _formKey.currentState!.value['email'] as String;
    _errors.remember({'email': email});
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final result = await ref
        .read(requestPasswordResetUseCaseProvider)
        .execute(email: email.trim());

    if (!mounted) return;
    final l10n = AppLocalizations.of(context);

    result.fold(
      // 429 has its own sentence there, and every other failure a reader's
      // one rather than the server's English (api-docs §0.14).
      (failure) => setState(() {
        _isSubmitting = false;
        _error = describeAuthFailure(failure, l10n);
      }),
      (_) {
        setState(() => _isSubmitting = false);
        AppUtils.showSnackBar(context, message: l10n.resetCodeSent);
        context.push(ResetPasswordConfirmRoute.location);
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
      title: l10n.resetPassword,
      subtitle: l10n.resetPasswordRequestIntro,
      children: [
        AuthErrorBanner(error: _errors.inBanner(_error)),
        AutofillGroup(
          child: FormBuilder(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: FormBuilderTextField(
              name: 'email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.email,
                hintText: l10n.emailHint,
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _errors.under(_error, 'email', _valueOf),
              ),
              validator: AuthFieldValidators.email(l10n),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
        AuthSubmitButton(
          label: l10n.sendCode,
          isBusy: _isSubmitting,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.x2),
        Center(
          child: TextButton(
            onPressed: () => context.push(ResetPasswordConfirmRoute.location),
            child: Text(l10n.haveCodeAlready),
          ),
        ),
      ],
    );
  }
}
