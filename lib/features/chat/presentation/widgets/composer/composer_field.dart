import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/domain/entities/message_limits.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The box you type into.
///
/// Grows a line at a time up to [maxLines] and then scrolls inside itself,
/// so a long message never pushes the conversation off screen. The growth is
/// animated rather than stepped: the field's own height changes in whole
/// lines, and letting that land instantly makes the whole composer jump.
class ComposerField extends StatelessWidget {
  const ComposerField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.length,
    this.hintText,
    this.onSubmitted,
  });

  /// One line to start, six at most — past that the text scrolls.
  static const int maxLines = 6;

  static const int minLines = 1;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;

  /// Characters currently typed, kept alongside the controller so the
  /// counter can be rebuilt without every listener rebuilding the field.
  final int length;

  final String? hintText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          alignment: Alignment.bottomCenter,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            minLines: minLines,
            maxLines: maxLines,
            // Deliberately no maxLength: the cap is enforced on send
            // (api-docs §5.4 answers MESSAGE_TOO_LONG at 4096), and a
            // formatter that silently swallows the tail of a paste is worse
            // than a counter that says what happened.
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            textCapitalization: TextCapitalization.sentences,
            style: theme.textTheme.bodyMedium,
            onSubmitted: onSubmitted,
            decoration: InputDecoration(
              hintText: hintText ?? l10n.messageHint,
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              isDense: true,
              filled: false,
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                vertical: AppSpacing.x2,
              ),
            ),
          ),
        ),
        ComposerCounter(length: length),
      ],
    );
  }
}

/// How much room is left, once there is a reason to care.
///
/// Silent for an ordinary message, then fading in at
/// [MessageLimits.counterVisibleFrom] and warming towards the danger colour
/// as the cap approaches — so the number arrives as a warning rather than as
/// a refusal.
class ComposerCounter extends StatelessWidget {
  const ComposerCounter({super.key, required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final visible = MessageLimits.showsCounter(length);
    final over = MessageLimits.isOverLimit(length);

    final colour = over
        ? chatix.danger
        : Color.lerp(
            theme.colorScheme.outline,
            chatix.danger,
            MessageLimits.pressure(length),
          );

    return AnimatedSize(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      alignment: Alignment.centerRight,
      child: !visible
          ? const SizedBox(height: 0, width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 2, right: AppSpacing.x1),
              child: Text(
                over
                    ? l10n.composerTooLongBy(
                        length - MessageLimits.maxContentLength,
                      )
                    : l10n.composerCharactersLeft(
                        MessageLimits.remaining(length),
                      ),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colour,
                  fontWeight: over ? FontWeight.w700 : FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
    );
  }
}
