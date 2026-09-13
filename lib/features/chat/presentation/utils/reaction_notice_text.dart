import 'package:chatix/features/chat/domain/entities/reaction_entity.dart';
import 'package:chatix/features/chat/presentation/providers/reaction_notice_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The one line a rolled-back reaction gets.
///
/// Separate from both the provider that raises it and the screen that shows
/// it: the provider layer has no localisations, and the sentence is worth
/// being able to check without pumping a screen.
String reactionNoticeText(AppLocalizations l10n, ReactionNoticeReason reason) =>
    switch (reason) {
      ReactionNoticeReason.disabled => l10n.reactionsDisabled,
      ReactionNoticeReason.notAllowed => l10n.reactionNotAllowed,
      ReactionNoticeReason.tooManyForUser => l10n.reactionLimitReached(
        ReactionLimits.maxPerUserPerMessage,
      ),
      ReactionNoticeReason.tooManyForMessage =>
        l10n.reactionMessageLimitReached(ReactionLimits.maxDistinctPerMessage),
      ReactionNoticeReason.tooFast => l10n.reactionTooFast,
      ReactionNoticeReason.failed => l10n.reactionFailed,
    };
