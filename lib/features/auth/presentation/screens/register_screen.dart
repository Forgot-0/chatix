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
import 'package:chatix/features/auth/presentation/utils/auth_form_errors.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_password_field.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:chatix/features/auth/presentation/widgets/oauth_buttons.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Registration.
///
/// `POST /users/register/` refuses a weak password at the schema level, with
/// a `422 VALIDATION` that names no rule (api-docs §3.2) — so the rules are
/// listed under the field and ticked off as they are met, before anything
/// is sent. The errors the server does pin to a field — `DUPLICATE_USER`
/// with its `{field, value}`, `PASSWORD_MISMATCH` — go onto that field
/// rather than into a banner nobody will connect to it.
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
  final _errors = AuthFormErrors(const {
    'username',
    'email',
    'password',
    'password_repeat',
  });

  AuthErrorInfo? _error;

  @override
  void dispose() {
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _repeatFocus.dispose();
    super.dispose();
  }

  String _currentPassword() => _valueOf('password');

  String _valueOf(String field) =>
      (_formKey.currentState?.fields[field]?.value as String?) ?? '';

  void _register() {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final values = _formKey.currentState!.value;
    final sent = {
      for (final field in _errors.fields) field: values[field] as String,
    };
    _errors.remember(sent);

    ref
        .read(authProvider.notifier)
        .register(
          username: sent['username']!.trim(),
          email: sent['email']!.trim(),
          password: sent['password']!,
          passwordRepeat: sent['password_repeat']!,
        );
  }

  /// "Passwords do not match" follows the password as it changes — but only
  /// once there is a repeat to compare with. Before that, checking the empty
  /// field would greet the reader with "repeat your password" while they
  /// are still typing the first one.
  void _recheckRepeat() {
    final repeat = _formKey.currentState?.fields['password_repeat'];
    if (repeat == null || _valueOf('password_repeat').isEmpty) return;
    repeat.validate(focusOnInvalid: false);
  }

  /// The server-side error for [field], while it still applies to what is in
  /// it.
  String? _serverErrorFor(String field) =>
      _errors.under(_error, field, _valueOf);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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

      final email = failed.email ?? _valueOf('email').trim();
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

    return AuthScaffold(
      title: l10n.registerHeadline,
      subtitle: l10n.registerSubtitle,
      children: [
        // A taken username or email is said on the field itself; the banner
        // is for everything else.
        AuthErrorBanner(error: _errors.inBanner(_error)),
        AutofillGroup(
          child: FormBuilder(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FormBuilderTextField(
                  name: 'username',
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newUsername],
                  onSubmitted: (_) => _emailFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: l10n.username,
                    hintText: l10n.usernameHint,
                    prefixIcon: const Icon(Icons.person_outline),
                    errorText: _serverErrorFor('username'),
                  ),
                  validator: AuthFieldValidators.username(l10n),
                ),
                const SizedBox(height: AppSpacing.x4),
                FormBuilderTextField(
                  name: 'email',
                  focusNode: _emailFocus,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _passwordFocus.requestFocus(),
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    hintText: l10n.emailHint,
                    prefixIcon: const Icon(Icons.email_outlined),
                    errorText: _serverErrorFor('email'),
                  ),
                  validator: AuthFieldValidators.email(l10n),
                ),
                const SizedBox(height: AppSpacing.x4),
                AuthPasswordField(
                  name: 'password',
                  focusNode: _passwordFocus,
                  labelText: l10n.password,
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
                  labelText: l10n.confirmPassword,
                  hintText: l10n.confirmPasswordHint,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: _serverErrorFor('password_repeat'),
                  onSubmitted: _register,
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
          label: l10n.registerSubmit,
          isBusy: isLoading,
          onPressed: _register,
        ),
        const OAuthSection(),
        const SizedBox(height: AppSpacing.x4),
        AuthSwitchPrompt(
          question: l10n.authHaveAccount,
          action: l10n.logIn,
          onPressed: () => context.go(LoginRoute.location),
        ),
      ],
    );
  }
}
