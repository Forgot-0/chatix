import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/illustrations/app_illustrations.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/email_verification_provider.dart';
import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_error_banner.dart';
import 'package:chatix/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// "Check your mail" — the screen between registering and being let in.
///
/// Built on [AuthScaffold] like the other signed-out screens: no app bar,
/// the envelope and the headline on top, the way back only when it was
/// pushed over another screen — and "Back to sign in" always.
///
/// Two things it does that a plain code box does not:
///
///  * **Auto-check.** Reading `GET /users/me/` cannot answer "is this
///    address confirmed yet" — that response is `{id, username, email}` and
///    nothing else (api-docs §3.9), so there is no status to poll. What the
///    client *can* do is notice the code itself: the clipboard is read when
///    the screen opens and every time the app comes back to the foreground,
///    which is exactly the moment someone returns from their mail app, and a
///    code found there is submitted without another tap.
///  * **A resend that respects the budget.** Both verification endpoints
///    allow 3 requests an hour (api-docs §3.6); the button counts down
///    instead of letting that be spent in three taps.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({this.email, super.key});

  /// The address the code was sent to, where the caller knows it.
  final String? email;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormBuilderState>();

  /// The clipboard text already offered, so returning to the app twice with
  /// the same stale code does not fire the same failed request again.
  String? _lastClipboardToken;

  bool _isChangingAddress = false;
  bool _filledFromClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = ref.read(emailVerificationProvider.notifier);
      controller.setEmail(widget.email);
      // Registration has just sent one; the countdown starts with the screen
      // rather than with the first tap on "send again".
      if (widget.email != null) controller.startCooldown();
      _autoCheckClipboard();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoCheckClipboard();
  }

  /// Pulls a verification code out of the clipboard and submits it.
  Future<void> _autoCheckClipboard() async {
    if (!mounted) return;
    if (ref.read(emailVerificationProvider).isConfirmed) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final token = extractVerificationToken(data?.text);
    if (token == null || token == _lastClipboardToken) return;
    if (!mounted) return;

    _lastClipboardToken = token;
    _formKey.currentState?.fields['token']?.didChange(token);
    setState(() => _filledFromClipboard = true);

    await _confirm(token);
  }

  Future<void> _confirm([String? token]) async {
    final code =
        token ??
        (_formKey.currentState?.saveAndValidate() ?? false
            ? _formKey.currentState!.value['token'] as String
            : null);
    if (code == null) return;

    if (!mounted) return;
    FocusScope.of(context).unfocus();

    final confirmed = await ref
        .read(emailVerificationProvider.notifier)
        .confirm(code);

    if (!mounted || !confirmed) return;

    AppUtils.showSnackBar(
      context,
      message: AppLocalizations.of(context).emailVerified,
    );
    context.go(LoginRoute.location);
  }

  Future<void> _resend() async {
    await ref.read(emailVerificationProvider.notifier).resend();
    if (!mounted) return;

    final state = ref.read(emailVerificationProvider);
    if (state.failure == null) {
      AppUtils.showSnackBar(
        context,
        message: AppLocalizations.of(context).verificationSent,
      );
    }
  }

  Future<void> _applyNewAddress() async {
    final field = _formKey.currentState?.fields['email'];
    if (!(field?.validate() ?? false)) return;

    ref
        .read(emailVerificationProvider.notifier)
        .setEmail(field!.value as String);
    setState(() => _isChangingAddress = false);
    await _resend();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = ref.watch(emailVerificationProvider);

    final error = state.failure == null
        ? null
        : describeAuthFailure(state.failure, l10n);
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    return AuthScaffold(
      header: const AppIllustration(
        kind: AppIllustrationKind.mail,
        size: AuthLayout.illustrationSize,
      ),
      title: l10n.verifyEmailHeadline,
      subtitle: state.email == null
          ? l10n.verifyEmailSentToYou
          : l10n.verifyEmailSentTo(state.email!),
      children: [
        Text(
          l10n.verifyEmailClipboardHint,
          textAlign: TextAlign.center,
          style: hintStyle,
        ),
        const SizedBox(height: AppSpacing.x5),
        AuthErrorBanner(error: error),
        FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormBuilderTextField(
                name: 'token',
                autocorrect: false,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                onSubmitted: (_) => _confirm(),
                decoration: InputDecoration(
                  labelText: l10n.verificationToken,
                  prefixIcon: const Icon(Icons.vpn_key_outlined),
                  helperText: _filledFromClipboard
                      ? l10n.verifyEmailCodeFromClipboard
                      : null,
                ),
                validator: AuthFieldValidators.required(l10n),
              ),
              const SizedBox(height: AppSpacing.x4),
              AuthSubmitButton(
                label: l10n.verify,
                isBusy: state.isConfirming,
                onPressed: state.isBusy ? null : () => _confirm(),
              ),
              const SizedBox(height: AppSpacing.x6),
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: AppSpacing.x4),
              Text(
                l10n.resendLimitHint,
                textAlign: TextAlign.center,
                style: hintStyle,
              ),
              const SizedBox(height: AppSpacing.x3),
              OutlinedButton.icon(
                onPressed: state.canResend ? _resend : null,
                icon: state.isSending
                    ? const SizedBox.square(
                        dimension: AppSpacing.x4,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.outgoing_mail),
                label: Text(
                  state.secondsUntilResend > 0
                      ? l10n.verifyEmailResendIn(state.secondsUntilResend)
                      : l10n.resendVerification,
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              if (_isChangingAddress) ...[
                FormBuilderTextField(
                  name: 'email',
                  initialValue: state.email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _applyNewAddress(),
                  decoration: InputDecoration(
                    labelText: l10n.email,
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  validator: AuthFieldValidators.email(l10n),
                ),
                const SizedBox(height: AppSpacing.x3),
                TextButton(
                  onPressed: state.isSending ? null : _applyNewAddress,
                  child: Text(l10n.resendVerification),
                ),
              ] else
                AuthSwitchPrompt(
                  question: l10n.verifyEmailWrongAddress,
                  action: l10n.verifyEmailChangeAddress,
                  onPressed: () => setState(() => _isChangingAddress = true),
                ),
            ],
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => context.go(LoginRoute.location),
            child: Text(l10n.backToSignIn),
          ),
        ),
      ],
    );
  }
}

/// Pulls a verification code out of whatever was copied.
///
/// The letter may put the code on its own or wrap it in a link; both are
/// handled, and anything that is neither — a paragraph of prose, an empty
/// clipboard, a code so long it cannot be one — is refused rather than
/// spent as one of the hour's three attempts.
String? extractVerificationToken(String? clipboard) {
  final raw = clipboard?.trim();
  if (raw == null || raw.isEmpty) return null;

  final uri = Uri.tryParse(raw);
  if (uri != null && uri.hasScheme) {
    final fromQuery = uri.queryParameters['token']?.trim();
    if (fromQuery != null && _looksLikeToken(fromQuery)) return fromQuery;

    final lastSegment = uri.pathSegments.isEmpty ? null : uri.pathSegments.last;
    if (lastSegment != null && _looksLikeToken(lastSegment)) return lastSegment;
    return null;
  }

  return _looksLikeToken(raw) ? raw : null;
}

/// One run of the characters a token is made of, long enough to be one and
/// short enough not to be a paragraph.
bool _looksLikeToken(String value) {
  if (value.length < 6 || value.length > 512) return false;
  return RegExp(r'^[A-Za-z0-9._~+/=-]+$').hasMatch(value);
}
