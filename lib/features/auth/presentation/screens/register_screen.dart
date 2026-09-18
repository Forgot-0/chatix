import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show TextInput;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_password_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Registration.
///
/// `POST /users/register/` refuses a weak password at the schema level, with
/// a `422 VALIDATION` that names no rule (api-docs §3.2) — so the rules are
/// enforced and shown here, under the field, before anything is sent. The
/// one error the server does localise for us is `DUPLICATE_USER`, which
/// carries `{field, value}`: it goes onto that field rather than into a
/// banner nobody will connect to it.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _repeatFocus = FocusNode();

  AuthErrorInfo? _error;

  /// What was sent on the last attempt, so a server-side error about a field
  /// can be dropped the moment that field is edited — the complaint was
  /// about the old value, not the new one.
  Map<String, String> _submitted = const <String, String>{};

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  String _currentPassword() =>
      (_formKey.currentState?.fields['password']?.value as String?) ?? '';

  String _valueOf(String field) =>
      (_formKey.currentState?.fields[field]?.value as String?)?.trim() ?? '';

  void _register() {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final values = _formKey.currentState!.value;
    _submitted = {
      'username': (values['username'] as String).trim(),
      'email': (values['email'] as String).trim(),
    };

    ref
        .read(authProvider.notifier)
        .register(
          username: (values['username'] as String).trim(),
          email: (values['email'] as String).trim(),
          password: values['password'] as String,
          passwordRepeat: values['password_repeat'] as String,
        );
  }

  /// The server-side error for [field], while it still applies to what is in
  /// it.
  String? _serverErrorFor(String field) {
    final error = _error;
    if (error == null || error.field != field) return null;
    if (_valueOf(field) != _submitted[field]) return null;
    return error.message;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final authState = ref.watch(authProvider);

    ref.listen(authProvider, (previous, next) {
      if (next.hasValue && next.value != null) {
        TextInput.finishAutofillContext();
        return;
      }
      if (next.isLoading || !next.hasError) return;

      // Registration worked and the sign-in behind it was refused only
      // because the address is not confirmed yet (api-docs §2.4). That is
      // not an error to sit on — it is the next screen.
      final failed = describeAuthFailure(next.error, l10n);
      if (failed.action != AuthErrorAction.resendVerification) return;

      final email = failed.email ?? _valueOf('email');
      if (email.isEmpty) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.push(VerifyEmailRoute.locationFor(email));
      });
    });

    final isLoading = authState.isLoading;

    _error = authState.hasError && !isLoading
        ? describeAuthFailure(authState.error, l10n)
        : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.register)),
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
                        Icons.person_add_alt,
                        size: 64,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: AppSpacing.x5),
                      Text(
                        l10n.registerHeadline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x2),
                      Text(
                        l10n.registerSubtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      // A duplicate username or email is said on the field
                      // itself; the banner is for everything else.
                      AuthErrorBanner(
                        error: _error?.field == null ? _error : null,
                      ),
                      FormBuilderTextField(
                        name: 'username',
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newUsername],
                        onSubmitted: (_) => _emailFocus.requestFocus(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.username,
                          hintText: l10n.usernameHint,
                          prefixIcon: const Icon(Icons.person_outline),
                          errorText: _serverErrorFor('username'),
                        ),
                        validator: AuthFieldValidators.username,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      FormBuilderTextField(
                        name: 'email',
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _passwordFocus.requestFocus(),
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: l10n.email,
                          hintText: l10n.emailHint,
                          prefixIcon: const Icon(Icons.email_outlined),
                          errorText: _serverErrorFor('email'),
                        ),
                        validator: AuthFieldValidators.email,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      AuthPasswordField(
                        name: 'password',
                        focusNode: _passwordFocus,
                        labelText: l10n.password,
                        hintText: l10n.passwordRule,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        showStrengthMeter: true,
                        onSubmitted: () => _repeatFocus.requestFocus(),
                        onChanged: (_) => _formKey
                            .currentState
                            ?.fields['password_repeat']
                            ?.validate(),
                        validator: AuthFieldValidators.password,
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      AuthPasswordField(
                        name: 'password_repeat',
                        focusNode: _repeatFocus,
                        labelText: l10n.confirmPassword,
                        hintText: l10n.confirmPasswordHint,
                        autofillHints: const [AutofillHints.newPassword],
                        onSubmitted: _register,
                        validator: AuthFieldValidators.passwordRepeat(
                          _currentPassword,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.x6),
                      FilledButton(
                        onPressed: isLoading ? null : _register,
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
                            : Text(l10n.register),
                      ),
                      const SizedBox(height: AppSpacing.x4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              l10n.authHaveAccount,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(LoginRoute.location),
                            child: Text(l10n.loginTitle),
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
