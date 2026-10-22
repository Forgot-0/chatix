import 'package:equatable/equatable.dart';

/// The five things a person decides who may do — the axes of
/// `PrivacySettingsDTO` (api-docs §4.14).
enum PrivacyRule {
  /// The "online" mark. The API has no last-seen time yet, only the flag.
  lastSeen('last_seen', 'last-seen'),

  /// The profile photo, and with it the whole photo history.
  photo('photo', 'photo'),

  /// Writing to a direct chat, starting one, forwarding into it, typing.
  messages('messages', 'messages'),

  /// Being added to groups and channels.
  groupInvites('group_invites', 'group-invites'),

  /// Calls in a direct chat.
  calls('calls', 'calls');

  const PrivacyRule(this.wire, this.slug);

  /// The key in the DTO.
  final String wire;

  /// The path segment the settings route uses.
  final String slug;

  static PrivacyRule? fromWire(String? value) {
    for (final rule in values) {
      if (rule.wire == value) return rule;
    }
    return null;
  }

  static PrivacyRule? fromSlug(String? value) {
    for (final rule in values) {
      if (rule.slug == value) return rule;
    }
    return null;
  }
}

/// Who a rule lets in, before exceptions.
enum PrivacyVisibility {
  /// Everybody — the default for every rule.
  everybody,

  /// People the owner of the setting keeps in *their own* address book.
  /// Somebody who added the owner does not count (api-docs §4.14).
  contacts,

  /// Nobody.
  nobody;

  String get wire => name;

  static PrivacyVisibility fromWire(Object? value) {
    for (final visibility in values) {
      if (visibility.wire == value) return visibility;
    }
    return PrivacyVisibility.everybody;
  }

  /// Whether a list of [kind] means anything under this value: "always
  /// allow" says nothing when everybody is allowed already, and "never
  /// allow" says nothing when nobody is. Both lists are kept either way —
  /// switching back brings the hidden one back, as in Telegram — they are
  /// only not offered.
  bool offers(PrivacyExceptionKind kind) => switch (this) {
    PrivacyVisibility.everybody => kind == PrivacyExceptionKind.deny,
    PrivacyVisibility.nobody => kind == PrivacyExceptionKind.allow,
    PrivacyVisibility.contacts => true,
  };
}

/// The two personal exception lists of a rule.
enum PrivacyExceptionKind {
  /// Let in whatever the rule says.
  allow('allow'),

  /// Kept out whatever the rule says.
  deny('deny');

  const PrivacyExceptionKind(this.slug);

  final String slug;

  PrivacyExceptionKind get other => this == PrivacyExceptionKind.allow
      ? PrivacyExceptionKind.deny
      : PrivacyExceptionKind.allow;

  static PrivacyExceptionKind? fromSlug(String? value) {
    for (final kind in values) {
      if (kind.slug == value) return kind;
    }
    return null;
  }
}

/// One rule's `allow` and `deny` lists, user ids in the order they were
/// added.
class PrivacyExceptions extends Equatable {
  const PrivacyExceptions({this.allow = const [], this.deny = const []});

  static const PrivacyExceptions none = PrivacyExceptions();

  /// `allow` and `deny` together, per rule — more is
  /// `400 PRIVACY_EXCEPTIONS_LIMIT` (api-docs §4.14).
  static const int limit = 100;

  final List<int> allow;
  final List<int> deny;

  int get total => allow.length + deny.length;

  bool get isEmpty => total == 0;

  List<int> of(PrivacyExceptionKind kind) =>
      kind == PrivacyExceptionKind.allow ? allow : deny;

  /// How many more [kind] can take before the rule is full.
  int roomFor(PrivacyExceptionKind kind) => limit - of(kind.other).length;

  /// [kind] replaced by [ids], and anybody in [ids] taken off the other
  /// list: one person is either always let in or never, not both. (The
  /// server would settle an overlap in favour of `allow`; the client never
  /// sends one.)
  PrivacyExceptions withList(PrivacyExceptionKind kind, Iterable<int> ids) {
    final next = <int>[];
    for (final id in ids) {
      if (!next.contains(id)) next.add(id);
    }
    final other = [
      for (final id in of(kind.other))
        if (!next.contains(id)) id,
    ];
    return kind == PrivacyExceptionKind.allow
        ? PrivacyExceptions(allow: next, deny: other)
        : PrivacyExceptions(allow: other, deny: next);
  }

  /// [kind] without [userId].
  PrivacyExceptions without(PrivacyExceptionKind kind, int userId) =>
      withList(kind, [
        for (final id in of(kind))
          if (id != userId) id,
      ]);

  @override
  List<Object?> get props => [allow, deny];
}

/// What `GET /profiles/privacy/` answers: a value per rule and the
/// exceptions to it.
///
/// Sparse on the client side: a rule missing from either map is at its
/// default — everybody, no exceptions — which is also what the server sends
/// for somebody who never changed anything.
class PrivacySettings extends Equatable {
  const PrivacySettings({this.rules = const {}, this.exceptions = const {}});

  static const PrivacySettings defaults = PrivacySettings();

  final Map<PrivacyRule, PrivacyVisibility> rules;
  final Map<PrivacyRule, PrivacyExceptions> exceptions;

  PrivacyVisibility visibilityOf(PrivacyRule rule) =>
      rules[rule] ?? PrivacyVisibility.everybody;

  PrivacyExceptions exceptionsOf(PrivacyRule rule) =>
      exceptions[rule] ?? PrivacyExceptions.none;

  PrivacySettings withVisibility(
    PrivacyRule rule,
    PrivacyVisibility visibility,
  ) => PrivacySettings(
    rules: {...rules, rule: visibility},
    exceptions: exceptions,
  );

  PrivacySettings withExceptions(PrivacyRule rule, PrivacyExceptions value) =>
      PrivacySettings(rules: rules, exceptions: {...exceptions, rule: value});

  @override
  List<Object?> get props => [
    for (final rule in PrivacyRule.values) ...[
      visibilityOf(rule),
      exceptionsOf(rule),
    ],
  ];
}
