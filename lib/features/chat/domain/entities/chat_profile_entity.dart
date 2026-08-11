import 'package:equatable/equatable.dart';

/// `ChatProfileDTO` (api-docs §6.3) — the denormalized copy of a user's
/// profile that the chat backend embeds directly into `MemberChatDTO.profile`
/// and `MessageDTO.profile`.
///
/// ### Why this is not `ProfileEntity`
///
/// `lib/features/profile` owns `ProfileDTO` (api-docs §4.3), a much richer
/// object: `avatars` is a nested `size -> format -> url` map, plus bio,
/// skills, contacts, birthday. What arrives inside a chat payload is a
/// deliberately flattened five-field snapshot with a single presigned
/// [avatarUrl].
///
/// These are two different bounded contexts that happen to describe the same
/// human right now. Reusing `ProfileEntity` here would force every chat
/// widget through a lossy adapter and, worse, would couple the chat module to
/// a DTO that evolves on the profiles team's schedule. They are free to
/// diverge — this copy only ever has to satisfy "render an author line in a
/// bubble".
///
/// ### Freshness
///
/// This is a *snapshot* denormalized at read time by the backend, not a live
/// view. It is authoritative enough for chat rendering (that is the entire
/// point of §6.3 — no extra `/profiles/{id}/` round trip for a name), but the
/// profile screen must still fetch the real `ProfileDTO`.
class ChatProfileEntity extends Equatable {
  /// Always equal to the owning `user_id` — there is no separate profile id
  /// (api-docs §4.1).
  final int userId;

  /// `null` for a profile that never set a username. Render `displayName`
  /// first and fall back through [ChatProfileEntity.bestName].
  final String? username;

  final String? displayName;

  /// ⚠️ A **presigned** URL generated on the fly by the backend (api-docs
  /// §6.3). It therefore expires — do not persist it in a local cache keyed
  /// by anything longer-lived than the current screen session. Cache the
  /// downloaded bytes against [avatarS3Key] instead, which is stable.
  final String? avatarUrl;

  /// The stable storage key behind [avatarUrl] — the correct cache key.
  final String? avatarS3Key;

  const ChatProfileEntity({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.avatarS3Key,
  });

  /// Best available human label, in the order a chat UI should prefer it:
  /// display name → `@username` → `User #id`.
  ///
  /// Lives here rather than in each widget so the fallback chain (and the
  /// `User #id` diagnostic form) stays identical everywhere.
  String get bestName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'User #$userId';
  }

  @override
  List<Object?> get props => [
    userId,
    username,
    displayName,
    avatarUrl,
    avatarS3Key,
  ];
}

/// Renders the author label for a possibly-missing profile.
///
/// `profile` is nullable all over §6.3/§6.4 (deleted user, profile not
/// materialized yet — see the eventual-consistency note in api-docs §0), so
/// every call site needs the same `User #id` fallback. Centralized here so
/// the diagnostic form is spelled one way.
String chatDisplayName(ChatProfileEntity? profile, int? userId) {
  if (profile != null) return profile.bestName;
  if (userId != null) return 'User #$userId';
  return 'unknown';
}
