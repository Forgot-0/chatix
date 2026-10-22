import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:chatix/core/router/app_layout.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/brand/chatix_logo.dart';
import 'package:chatix/core/ui/wallpaper/mesh_wallpaper.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';

/// The page every signed-out form is built on: sign in, sign up, both steps
/// of the password reset.
///
/// No app bar. The headline under the mark already says where the reader
/// is, and a bar titled "Login" over "Welcome back" said it twice. What a
/// bar is still good for — the way back — is drawn on its own, and only
/// when there is somewhere to go back to: the reset screens are pushed over
/// sign-in, but sign-in and sign-up replace each other and lead nowhere.
///
/// The form is one column no wider than [AppContentWidths.auth], centred in
/// whatever room the page is given — measured here, not taken from the
/// window. With room to spare (a tablet, a desktop window) the column sits
/// on a card over the reader's own chat wallpaper, rather than as a narrow
/// strip in the middle of an empty screen.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.children,
    this.subtitle,
    this.header = const ChatixLogo(),
    super.key,
  });

  /// Over the headline: the mark, or a picture that says what this step is.
  final Widget header;

  final String title;
  final String? subtitle;

  /// The form, top to bottom, stretched to the column's width.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final canGoBack = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: header),
        const SizedBox(height: AppSpacing.x6),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (subtitle case final subtitle?) ...[
          const SizedBox(height: AppSpacing.x2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: AuthLayout.headerGap),
        ...children,
      ],
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final onCard = constraints.maxWidth >= AppBreakpoints.medium;

          final form = onCard
              ? _AuthCard(child: column)
              : AppContentWidth(maxWidth: AppContentWidths.auth, child: column);

          final page = SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canGoBack)
                  const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.x1),
                      child: BackButton(),
                    ),
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, viewport) => SingleChildScrollView(
                      padding: const EdgeInsets.all(AuthLayout.gutter),
                      child: ConstrainedBox(
                        // At least the viewport's height, so a short form
                        // sits in the middle of the page rather than at
                        // its top, and a long one still scrolls.
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            viewport.maxHeight - AuthLayout.gutter * 2,
                          ),
                        ),
                        child: Center(child: form),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );

          if (!onCard) return page;

          return MeshWallpaperView(
            spec: wallpaperSpecOf(context),
            ground: ChatixTheme.of(context).chatBackground,
            child: page,
          );
        },
      ),
    );
  }
}

/// The form's own surface on a wide page. A hairline rather than a shadow:
/// on the dark theme's near-black a shadow says nothing.
class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: AppContentWidths.auth + AuthLayout.cardPadding * 2,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(AuthLayout.cardRadius),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AuthLayout.cardPadding),
          child: child,
        ),
      ),
    );
  }
}

/// The one filled button a form ends on, with its spinner while the request
/// is out.
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    super.key,
  });

  final String label;

  /// Null leaves the button disabled, as while another request is out.
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isBusy ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
      ),
      child: isBusy
          ? const SizedBox.square(
              dimension: AppSpacing.x5,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

/// "Don't have an account? Sign up" — the way across to the other form.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    required this.question,
    required this.action,
    required this.onPressed,
    super.key,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
