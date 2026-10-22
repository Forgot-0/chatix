import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';

/// `PrivacySettingsDTO` and `PrivacySettingsUpdateRequest` (api-docs §4.14),
/// read and written by hand.
///
/// A rule or a value this build does not know is skipped rather than
/// failing the read: a server that grows a sixth rule should not cost the
/// five the screen knows about.
abstract final class PrivacySettingsModel {
  static PrivacySettings fromJson(Map<String, dynamic> json) {
    final rules = <PrivacyRule, PrivacyVisibility>{};
    final rawRules = json['rules'];
    if (rawRules is Map) {
      for (final MapEntry(:key, :value) in rawRules.entries) {
        final rule = PrivacyRule.fromWire('$key');
        if (rule != null) rules[rule] = PrivacyVisibility.fromWire(value);
      }
    }

    final exceptions = <PrivacyRule, PrivacyExceptions>{};
    final rawExceptions = json['exceptions'];
    if (rawExceptions is Map) {
      for (final MapEntry(:key, :value) in rawExceptions.entries) {
        final rule = PrivacyRule.fromWire('$key');
        if (rule == null || value is! Map) continue;
        exceptions[rule] = PrivacyExceptions(
          allow: _ids(value['allow']),
          deny: _ids(value['deny']),
        );
      }
    }

    return PrivacySettings(rules: rules, exceptions: exceptions);
  }

  /// The partial update: only the rules and lists that change. Each list
  /// is sent whole — the server replaces, it does not merge.
  static Map<String, dynamic> updateJson({
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  }) {
    return {
      if (rules.isNotEmpty)
        'rules': {
          for (final MapEntry(key: rule, value: visibility) in rules.entries)
            rule.wire: visibility.wire,
        },
      if (exceptions.isNotEmpty)
        'exceptions': {
          for (final MapEntry(key: rule, value: lists) in exceptions.entries)
            rule.wire: {'allow': lists.allow, 'deny': lists.deny},
        },
    };
  }

  static List<int> _ids(Object? raw) => [
    if (raw is List)
      for (final id in raw)
        if (id is num) id.toInt(),
  ];
}
