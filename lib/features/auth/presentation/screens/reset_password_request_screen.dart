import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

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
      // 429 has its own sentence there, and every other failure a reader's
      // one rather than the server's English (api-docs §0.14).
      (failure) => AppUtils.showSnackBar(
        context,
        message: describeAuthFailure(
          failure,
          AppLocalizations.of(context),
        ).message,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) {
        AppUtils.showSnackBar(
          context,
          message: AppLocalizations.of(context).resetCodeSent,
        );
        context.push(ResetPasswordConfirmRoute.location);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPassword)),
      // A form column, not the window's width: outside the shell there is
      // no pane to hold it in, and a 1400 px email field reads as broken.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.x6),
        child: AppContentWidth(
          child: FormBuilder(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.resetPasswordRequestIntro),
                const SizedBox(height: 24),
                FormBuilderTextField(
                  name: 'email',
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).email,
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: AuthFieldValidators.email(l10n),
                ),
                const SizedBox(height: 24),
                // The same primary button as signing in, rather than a
                // Material default that reads as a link in this theme.
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.x4,
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(AppLocalizations.of(context).sendCode),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        context.push(ResetPasswordConfirmRoute.location),
                    child: Text(AppLocalizations.of(context).haveCodeAlready),
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
