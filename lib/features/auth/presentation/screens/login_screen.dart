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
import 'package:chatix/features/auth/presentation/utils/auth_form_errors.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_password_field.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_scaffold.dart';
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
  final _errors = AuthFormErrors(const {'username', 'password'});

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

  String _valueOf(String field) =>
      (_formKey.currentState?.fields[field]?.value as String?) ?? '';

  String _identifier() => _valueOf('username').trim();

  void _login() {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final values = _formKey.currentState!.value;
    final username = values['username'] as String;
    final password = values['password'] as String;
    _errors.remember({'username': username, 'password': password});

    ref
        .read(authProvider.notifier)
        .login(username: username.trim(), password: password);
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

    return AuthScaffold(
      title: l10n.loginHeadline,
      subtitle: l10n.loginSubtitle,
      children: [
        AuthErrorBanner(
          error: _errors.inBanner(_error),
          actionLabel: l10n.authResendEmail,
          isActionBusy: _isResending,
          onAction: _resendVerification,
        ),
        AutofillGroup(
          child: FormBuilder(
            key: _formKey,
            // Every edit may retire a server error: "wrong username or
            // password" is about what was sent, not what is typed now.
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormBuilderTextField(
                  name: 'username',
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
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
                  validator: AuthFieldValidators.loginIdentifier(l10n),
                ),
                const SizedBox(height: AppSpacing.x4),
                AuthPasswordField(
                  name: 'password',
                  focusNode: _passwordFocus,
                  labelText: l10n.password,
                  hintText: l10n.passwordHint,
                  errorText: _errors.under(
                    _error,
                    'password',
                    _valueOf,
                    alsoAbout: const {'username'},
                  ),
                  onSubmitted: _login,
                  validator: AuthFieldValidators.required(l10n),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(
            onPressed: () => context.push(ResetPasswordRoute.location),
            child: Text(l10n.forgotPassword),
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        AuthSubmitButton(
          label: l10n.logIn,
          isBusy: isLoading,
          onPressed: _login,
        ),
        const OAuthSection(),
        const SizedBox(height: AppSpacing.x4),
        AuthSwitchPrompt(
          question: l10n.authNoAccount,
          action: l10n.register,
          onPressed: () => context.go(RegisterRoute.location),
        ),
      ],
    );
  }
}
