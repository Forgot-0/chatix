import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';

import 'package:chatix/features/chat/domain/entities/chat_member_entity.dart';

/// What an `@mention` looks like in message text — one definition, for the
/// composer that writes one and the bubble that finds it again.
///
/// The API has no mention entities: a message is plain `content`
/// (api-docs §5.4), so a mention is nothing but `@` and a username in the
/// text, recognised again when the bubble is drawn
/// (`MessageLinkifier`). Usernames may be `^[a-zA-Z0-9 ,.'-]+$` (api-docs
/// §3.2) — spaces, commas and apostrophes included — and no pattern can tell
/// where such a handle ends inside a sentence. So only usernames that read
/// back unambiguously are offered: letters, digits, `.`, `_` and `-`, not
/// ending in a dot (the bubble hands a trailing dot back to the sentence).
abstract final class MentionSyntax {
  /// The handle after the `@`, as the bubble matches it.
  static const String handlePattern = '[A-Za-z0-9][A-Za-z0-9._-]{0,99}';

  /// What may stand right before the `@` of a mention: anything but the
  /// tail of a word or an address — the same rule the bubble applies.
  static const String boundaryLookbehind = r'(?<![A-Za-z0-9_@.])';

  static final RegExp _whole = RegExp('^$handlePattern\$');

  /// Characters a query may be typed with after the `@`. Wider than a
  /// handle: "@Лин" is someone looking for Линус by name.
  static final RegExp _queryChar = RegExp(r'[\p{L}\p{N}._-]', unicode: true);

  static final RegExp _boundaryChar = RegExp(r'[A-Za-z0-9_@.]');

  /// Whether [username] can be mentioned so that the bubble finds it again.
  static bool isMentionable(String? username) {
    if (username == null) return false;
    return _whole.hasMatch(username) && !username.endsWith('.');
  }

  /// The text a picked mention becomes: the handle and a space, so typing
  /// goes on after it.
  static String insertionFor(String username) => '@$username ';

  /// The `@query` the caret is in, or null when it is not in one.
  ///
  /// A query starts at an `@` that begins a word and runs over query
  /// characters up to the caret — and on past it to the end of the word,
  /// so picking a name with the caret mid-word replaces the whole word
  /// rather than leaving its tail behind. A selection is not a query.
  static MentionQuery? queryAt(TextEditingValue value) {
    final selection = value.selection;
    if (!selection.isValid || !selection.isCollapsed) return null;

    final text = value.text;
    final caret = selection.baseOffset.clamp(0, text.length);

    var start = caret;
    while (start > 0 && _isQueryChar(text[start - 1])) {
      start--;
    }
    if (start == 0 || text[start - 1] != '@') return null;

    final at = start - 1;
    if (at > 0 && _boundaryChar.hasMatch(text[at - 1])) return null;

    var end = caret;
    while (end < text.length && _isQueryChar(text[end])) {
      end++;
    }

    return MentionQuery(
      start: at,
      end: end,
      query: text.substring(start, caret),
    );
  }

  static bool _isQueryChar(String char) => _queryChar.hasMatch(char);
}

/// The `@...` being typed: where it sits in the text and what has been
/// typed of it so far.
class MentionQuery extends Equatable {
  const MentionQuery({
    required this.start,
    required this.end,
    required this.query,
  });

  /// The `@` itself.
  final int start;

  /// Just past the word the caret is in.
  final int end;

  /// What was typed between the `@` and the caret, without the `@`.
  final String query;

  @override
  List<Object?> get props => [start, end, query];
}

/// Who an `@query` could mean, best match first.
///
/// Looks at the username and at the display name, case-insensitively. A
/// username that starts with the query beats a name that does, which beats
/// a later word of the name, which beats a match inside either — so `@al`
/// puts Alan above Natalia. Ties go alphabetically by the name shown.
///
/// Never offers the writer, a banned member, or anyone whose username could
/// not be read back out of the message ([MentionSyntax.isMentionable]).
List<ChatMemberEntity> mentionCandidates(
  Iterable<ChatMemberEntity> members,
  String query, {
  required int? myUserId,
  int limit = 50,
}) {
  final needle = query.trim().toLowerCase();
  final ranked = <({ChatMemberEntity member, int score, String sortKey})>[];
  final seen = <int>{};

  for (final member in members) {
    if (member.userId == myUserId || member.isBanned) continue;
    if (!seen.add(member.userId)) continue;

    final username = member.profile?.username;
    if (!MentionSyntax.isMentionable(username)) continue;

    final handle = username!.toLowerCase();
    final name = member.profile?.displayName?.trim().toLowerCase() ?? '';

    final score = needle.isEmpty
        ? 0
        : handle.startsWith(needle)
        ? 0
        : name.startsWith(needle)
        ? 1
        : name.split(RegExp(r'\s+')).skip(1).any((w) => w.startsWith(needle))
        ? 2
        : handle.contains(needle) || name.contains(needle)
        ? 3
        : null;
    if (score == null) continue;

    ranked.add((
      member: member,
      score: score,
      sortKey: name.isEmpty ? handle : name,
    ));
  }

  ranked.sort((a, b) {
    final byScore = a.score.compareTo(b.score);
    return byScore != 0 ? byScore : a.sortKey.compareTo(b.sortKey);
  });

  return [for (final hit in ranked.take(limit)) hit.member];
}
