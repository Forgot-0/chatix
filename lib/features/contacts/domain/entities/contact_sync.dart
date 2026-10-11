import 'package:equatable/equatable.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';

/// One page of `GET /contacts/` — `ContactListDTO` (api-docs §4.8).
class ContactPage extends Equatable {
  const ContactPage({
    required this.contacts,
    required this.hasNext,
    this.nextContactId,
    this.version,
  });

  final List<Contact> contacts;
  final bool hasNext;

  /// What to send as `after_contact_id` for the next page.
  final int? nextContactId;

  /// The delta-sync mark. Only the last page carries one (`has_next=false`).
  final String? version;

  @override
  List<Object?> get props => [contacts, hasNext, nextContactId, version];
}

/// The address book as this device last saw it, and how fresh that is.
class ContactsSnapshot extends Equatable {
  const ContactsSnapshot({
    required this.ownerId,
    this.contacts = const <Contact>[],
    this.version,
    this.fullSyncAt,
  });

  /// Whose book this is. A book left by another account is never shown.
  final int ownerId;

  final List<Contact> contacts;

  /// Sent as `updated_after` on the next sync to read only what changed.
  /// Null until a read has reached the last page.
  final String? version;

  /// When the whole list was last read from the start. Deletions never come
  /// through a delta (api-docs §4.8), so this is how old they can be.
  final DateTime? fullSyncAt;

  ContactsSnapshot copyWith({
    List<Contact>? contacts,
    String? Function()? version,
    DateTime? Function()? fullSyncAt,
  }) {
    return ContactsSnapshot(
      ownerId: ownerId,
      contacts: contacts ?? this.contacts,
      version: version == null ? this.version : version(),
      fullSyncAt: fullSyncAt == null ? this.fullSyncAt : fullSyncAt(),
    );
  }

  @override
  List<Object?> get props => [ownerId, contacts, version, fullSyncAt];
}

/// When a delta is not enough and the whole list has to be read again.
class ContactSyncPolicy {
  const ContactSyncPolicy({this.fullEvery = const Duration(days: 7)});

  /// Deletions are invisible to a delta, so a contact removed on another
  /// device lingers here until the next full read — at most this long.
  final Duration fullEvery;

  static const ContactSyncPolicy defaults = ContactSyncPolicy();

  /// Whether the next sync of [snapshot] for [ownerId] has to start over.
  ///
  /// It does with nothing cached (a fresh install, or the first sign-in on
  /// this device — signing out clears the book), with a book that belongs to
  /// somebody else, with no `version` to send, and once [fullEvery] has
  /// passed since the last full read.
  bool needsFullSync(
    ContactsSnapshot? snapshot, {
    required int ownerId,
    required DateTime now,
  }) {
    if (snapshot == null || snapshot.ownerId != ownerId) return true;
    if (snapshot.version == null) return true;

    final fullAt = snapshot.fullSyncAt;
    if (fullAt == null) return true;
    return now.difference(fullAt) >= fullEvery;
  }
}
