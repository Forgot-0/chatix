import 'package:equatable/equatable.dart';

import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';

/// Which parts of a profile the app shows. One switch per decision, so a
/// product call is a one-line change rather than a hunt through screens.
abstract final class ProfileFieldVisibility {
  /// "Specialization" and "Skills" — left over from the template the app
  /// started from, and nothing a messenger profile asks for.
  ///
  /// Off: neither shown on a profile nor offered by the edit form. The API
  /// fields are untouched — `ProfileDTO` still carries them and the edit form
  /// still sends back whatever the profile held, because `PUT /profiles/{id}/`
  /// would otherwise wipe them (api-docs §4.4). Turning this on brings both
  /// back as they were.
  static const bool workFields = false;
}

/// The line under a person's name.
///
/// Presence is a yes/no read off a direct chat's member list (api-docs
/// §5.3): there is no `last_seen_at` anywhere in the API and no presence for
/// someone this account has no chat with. So "last seen recently" is said
/// only of someone known to be away right now — never guessed for a person
/// nothing is known about.
enum ProfilePresence {
  /// Online right now — said in the accent.
  online,

  /// Known to be offline: "last seen recently".
  recently,

  /// Nothing true to say; the line is left out.
  unknown;

  /// [online] is the direct chat's presence answer, null while there is
  /// none. One's own profile is always online: it is being looked at.
  static ProfilePresence of({required bool isMe, required bool? online}) {
    if (isMe) return ProfilePresence.online;
    return switch (online) {
      true => ProfilePresence.online,
      false => ProfilePresence.recently,
      null => ProfilePresence.unknown,
    };
  }
}

/// The round buttons under a profile's header.
enum ProfileQuickAction { message, call, mute, unmute, more, share, qr }

/// What "More" on somebody else's profile offers.
enum ProfileMenuAction {
  share,
  addContact,
  rename,
  removeContact,
  block,
  unblock;

  /// Drawn in the danger colour, under a rule.
  bool get isDestructive =>
      this == ProfileMenuAction.removeContact ||
      this == ProfileMenuAction.block;
}

/// Which actions a profile offers, and which of them can be pressed.
abstract final class ProfileActions {
  /// Somebody else: write, call, silence their chat, and the rest behind
  /// "More". Oneself: no chat to open or silence — share and the QR code.
  ///
  /// [muted] is whether the direct chat is silenced; null when there is no
  /// chat or its state is not loaded, which reads as "not silenced".
  static List<ProfileQuickAction> quickFor({required bool isMe, bool? muted}) {
    if (isMe) return const [ProfileQuickAction.share, ProfileQuickAction.qr];

    return [
      ProfileQuickAction.message,
      ProfileQuickAction.call,
      muted == true ? ProfileQuickAction.unmute : ProfileQuickAction.mute,
      ProfileQuickAction.more,
    ];
  }

  /// Whether [action] can be pressed now. A greyed button keeps the row's
  /// shape where a missing one would make it jump.
  ///
  /// * [busy] — a direct chat is being found or created: writing and
  ///   calling both wait for it, so neither can be asked for twice;
  /// * [blocked] — no calls to a person one has blocked; writing still
  ///   opens the chat, where the composer offers to unblock;
  /// * [hasDirectChat] — silencing is a setting of the chat, and there is
  ///   no chat to silence until one exists.
  static bool isEnabled(
    ProfileQuickAction action, {
    required bool busy,
    required bool blocked,
    required bool hasDirectChat,
  }) {
    return switch (action) {
      ProfileQuickAction.message => !busy,
      ProfileQuickAction.call => !busy && !blocked,
      ProfileQuickAction.mute || ProfileQuickAction.unmute => hasDirectChat,
      ProfileQuickAction.more ||
      ProfileQuickAction.share ||
      ProfileQuickAction.qr => true,
    };
  }

  /// "More": share first, the address book in the middle, blocking last —
  /// the reversible things nearest the finger.
  static List<ProfileMenuAction> menuFor({
    required bool isContact,
    required bool isBlocked,
  }) {
    return [
      ProfileMenuAction.share,
      if (isContact) ...[
        ProfileMenuAction.rename,
        ProfileMenuAction.removeContact,
      ] else
        ProfileMenuAction.addContact,
      if (isBlocked) ProfileMenuAction.unblock else ProfileMenuAction.block,
    ];
  }
}

/// The facts a profile shows, tidied: blank text is no text, and the work
/// fields are there only when [ProfileFieldVisibility.workFields] says so.
class ProfileFacts extends Equatable {
  const ProfileFacts({
    required this.username,
    this.bio,
    this.birthday,
    this.links = const [],
    this.specialization,
    this.skills = const [],
  });

  factory ProfileFacts.of(
    ProfileEntity profile, {
    bool workFields = ProfileFieldVisibility.workFields,
  }) {
    return ProfileFacts(
      username: profile.username.trim(),
      bio: _text(profile.bio),
      birthday: profile.dateBirthday,
      links: profile.contacts,
      specialization: workFields ? _text(profile.specialization) : null,
      skills: workFields ? profile.skills : const [],
    );
  }

  /// Without the `@`. Every profile has one (api-docs §4.3).
  final String username;

  final String? bio;

  /// A calendar day; `date_birthday` is a plain `YYYY-MM-DD`.
  final DateTime? birthday;

  /// `ProfileDTO.links` — github, a site, a Telegram handle.
  final List<ContactEntity> links;

  final String? specialization;
  final List<String> skills;

  /// `@username`, as the row and the clipboard have it.
  String get handle => '@$username';

  /// Nothing but the handle: the person has not filled anything in.
  bool get isBlank =>
      bio == null &&
      birthday == null &&
      links.isEmpty &&
      specialization == null &&
      skills.isEmpty;

  static String? _text(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  @override
  List<Object?> get props => [
    username,
    bio,
    birthday,
    links,
    specialization,
    skills,
  ];
}
