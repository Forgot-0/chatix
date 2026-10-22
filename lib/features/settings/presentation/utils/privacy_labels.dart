import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What each rule is called, what it asks, and what it means.
extension PrivacyRuleLabels on PrivacyRule {
  String title(AppLocalizations l10n) => switch (this) {
    PrivacyRule.lastSeen => l10n.privacyRuleLastSeen,
    PrivacyRule.photo => l10n.privacyRulePhoto,
    PrivacyRule.messages => l10n.privacyRuleMessages,
    PrivacyRule.groupInvites => l10n.privacyRuleGroupInvites,
    PrivacyRule.calls => l10n.privacyRuleCalls,
  };

  /// The caption over the three answers: "Who can see …".
  String question(AppLocalizations l10n) => switch (this) {
    PrivacyRule.lastSeen => l10n.privacyQuestionLastSeen,
    PrivacyRule.photo => l10n.privacyQuestionPhoto,
    PrivacyRule.messages => l10n.privacyQuestionMessages,
    PrivacyRule.groupInvites => l10n.privacyQuestionGroupInvites,
    PrivacyRule.calls => l10n.privacyQuestionCalls,
  };

  /// Under the answers: what the rule reaches, and what it does not.
  String footer(AppLocalizations l10n) => switch (this) {
    PrivacyRule.lastSeen => l10n.privacyFooterLastSeen,
    PrivacyRule.photo => l10n.privacyFooterPhoto,
    PrivacyRule.messages => l10n.privacyFooterMessages,
    PrivacyRule.groupInvites => l10n.privacyFooterGroupInvites,
    PrivacyRule.calls => l10n.privacyFooterCalls,
  };
}

extension PrivacyVisibilityLabels on PrivacyVisibility {
  String label(AppLocalizations l10n) => switch (this) {
    PrivacyVisibility.everybody => l10n.privacyEverybody,
    PrivacyVisibility.contacts => l10n.privacyMyContacts,
    PrivacyVisibility.nobody => l10n.privacyNobody,
  };
}

extension PrivacyExceptionKindLabels on PrivacyExceptionKind {
  String title(AppLocalizations l10n) => switch (this) {
    PrivacyExceptionKind.allow => l10n.privacyAlwaysAllow,
    PrivacyExceptionKind.deny => l10n.privacyNeverAllow,
  };
}

/// A rule as its row in Privacy sums it up: the answer, and — Telegram's
/// shorthand — how many people the lists that count under it take out or
/// let in: "My contacts (−2, +1)".
///
/// A list the answer makes meaningless is left out of the sum, the way it
/// is left off the rule's own page.
String privacyValueSummary(
  AppLocalizations l10n,
  PrivacyVisibility visibility,
  PrivacyExceptions exceptions,
) {
  final changes = [
    if (visibility.offers(PrivacyExceptionKind.deny) &&
        exceptions.deny.isNotEmpty)
      l10n.privacyExceptionsMinus(exceptions.deny.length),
    if (visibility.offers(PrivacyExceptionKind.allow) &&
        exceptions.allow.isNotEmpty)
      l10n.privacyExceptionsPlus(exceptions.allow.length),
  ];
  final value = visibility.label(l10n);
  if (changes.isEmpty) return value;
  return l10n.privacyValueWithExceptions(value, changes.join(', '));
}
