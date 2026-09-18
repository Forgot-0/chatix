import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_password_field.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_buttons.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Sign in.
///
/// The one thing on this screen that is easy to get wrong and impossible to
/// see: `POST /auth/login/` is `application/x-www-form-urlencoded` with
/// fields named `username` and `password` — not JSON, and not `email`
/// (api-docs §0.4, §3.3). The field is named `username` here all the way
/// down to the data source for exactly that reason, even though people will
/// type their email into it.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _passwordFocus = FocusNode();

  /// The failure the last attempt came back with, recomputed in `build` from
  /// the auth state rather than pushed in from a listener — a listener would
  /// have to `setState` from inside another widget's build.
  AuthErrorInfo? _error;
  bool _isResending = false;

  @override
  void dispose() {
    _passwordFocus.dispose();
    super.dispose();
  }

  String _identifier() =>
      (_formKey.currentState?.fields['username']?.value as String?)?.trim() ??
      '';

  void _login() {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final values = _formKey.currentState!.value;
    ref
        .read(authProvider.notifier)
        .login(
          username: (values['username'] as String).trim(),
          password: values['password'] as String,
        );
  }

  /// `EMAIL_NOT_CONFIRMED` is the one failure with a way out of it: the
  /// account is real and the password was right, so send the letter again
  /// and move on to the screen that waits for it.
  Future<void> _resendVerification() async {
    final email = _error?.email ?? _identifier();
    if (email.isEmpty) return;

    setState(() => _isResending = true);

    final result = await ref
        .read(requestEmailVerificationUseCaseProvider)
        .execute(email: email);

    if (!mounted) return;
    setState(() => _isResending = false);

    final l10n = AppLocalizations.of(context);
    result.match(
      (failure) => AppUtils.showSnackBar(
        context,
        message: describeAuthFailure(failure, l10n).message,
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
      (_) {
        AppUtils.showSnackBar(context, message: l10n.verificationSent);
        context.push(VerifyEmailRoute.locationFor(email));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      // Only once the sign-in has actually worked: this is what makes the
      // platform offer to save the credentials that just got someone in.
      if (next.hasValue && next.value != null) {
        TextInput.finishAutofillContext();
      }
    });

    final isLoading = authState.isLoading;

    _error = authState.hasError && !isLoading
        ? describeAuthFailure(authState.error, l10n)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.x6),
          child: Center(
            child: SingleChildScrollView(
              child: AutofillGroup(
                child: FormBuilder(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 72,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      Text(
                        l10n.loginHeadline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        l10n.loginSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      AuthErrorBanner(
                        error: _error,
                        actionLabel: l10n.authResendEmail,
                        isActionBusy: _isResending,
                        onAction: _resendVerification,
                      ),
                      FormBuilderTextField(
                        name: 'username',
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        decoration: InputDecoration(
                          labelText: l10n.emailOrUsername,
                          hintText: l10n.emailOrUsernameHint,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: AuthFieldValidators.loginIdentifier,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      AuthPasswordField(
                        name: 'password',
                        focusNode: _passwordFocus,
                        labelText: l10n.password,
                        hintText: l10n.passwordHint,
                        onSubmitted: _login,
                        validator: AuthFieldValidators.required,
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () =>
                              context.push(ResetPasswordRoute.location),
                          child: Text(l10n.forgotPassword),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      FilledButton(
                        onPressed: isLoading ? null : _login,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.x4,
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.logIn),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      if (oauthSignInEnabled) ...[
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x3,
                              ),
                              child: Text(
                                l10n.authOrContinueWith,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.x4),
                        const OAuthButtons(),
                        const SizedBox(height: AppSpacing.x4),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.authNoAccount,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(RegisterRoute.location),
                            child: Text(l10n.register),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
