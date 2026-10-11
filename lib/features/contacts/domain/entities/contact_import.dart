import 'package:equatable/equatable.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';

/// One address-book entry to match — an item of `ImportContactsRequest`
/// (api-docs §4.11). Email is the only identifier the API takes.
class ContactImportEntry extends Equatable {
  const ContactImportEntry({
    required this.email,
    this.firstName,
    this.lastName,
  });

  final String email;
  final String? firstName;
  final String? lastName;

  @override
  List<Object?> get props => [email, firstName, lastName];
}

enum ContactImportStatus {
  /// Up to [ContactImportLimits.syncBatch] entries: matched on the spot.
  done,

  /// A bigger batch: accepted, matched in the background, reported over the
  /// socket as `contacts_import_completed`.
  queued,
}

/// `ImportContactsResultDTO` (api-docs §4.11).
class ContactImportResult extends Equatable {
  const ContactImportResult({
    required this.status,
    required this.accepted,
    this.matched = 0,
    this.pending = 0,
    this.invalid = 0,
    this.contacts = const <Contact>[],
  });

  final ContactImportStatus status;
  final int accepted;

  /// Found among registered users. Zero while [status] is queued.
  final int matched;

  /// Kept until the owner of the address registers.
  final int pending;

  /// Not recognised as an email.
  final int invalid;

  /// The new contacts, when [status] is done.
  final List<Contact> contacts;

  @override
  List<Object?> get props => [
    status,
    accepted,
    matched,
    pending,
    invalid,
    contacts,
  ];
}

/// The `contacts_import_completed` socket event's payload (api-docs §4.13).
class ContactImportReport extends Equatable {
  const ContactImportReport({
    required this.ownerId,
    required this.accepted,
    required this.matched,
    required this.pending,
    required this.invalid,
  });

  final int ownerId;
  final int accepted;
  final int matched;
  final int pending;
  final int invalid;

  @override
  List<Object?> get props => [ownerId, accepted, matched, pending, invalid];
}

abstract final class ContactImportLimits {
  /// Up to this many entries the server answers `200` with the result.
  static const int syncBatch = 100;

  /// More than this in one request is a `422` (api-docs §4.11).
  static const int maxBatch = 500;
}

/// What [ContactImportParser] made of a pasted list.
class ContactImportDraft extends Equatable {
  const ContactImportDraft({
    this.entries = const <ContactImportEntry>[],
    this.rejected = const <String>[],
  });

  /// One per address, duplicates dropped.
  final List<ContactImportEntry> entries;

  /// Lines with no address in them, as typed.
  final List<String> rejected;

  bool get isEmpty => entries.isEmpty;

  @override
  List<Object?> get props => [entries, rejected];
}

/// Reads addresses out of whatever was pasted: one per line, a comma list,
/// or an address-book export like `Ivan Petrov <ivan@example.com>`.
///
/// A line with exactly one address gives the rest of the line as the name —
/// the first word as `first_name`, everything after as `last_name`. A line
/// with several gives the addresses alone, since there is no telling whose
/// name is whose.
abstract final class ContactImportParser {
  static final RegExp _email = RegExp(
    r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+",
  );

  /// What is left of a line around its address that is not a name.
  static final RegExp _nameNoise = RegExp(r'''[<>()\[\]"'«»,;:|\t]+''');

  static ContactImportDraft parse(String text) {
    final entries = <ContactImportEntry>[];
    final rejected = <String>[];
    final seen = <String>{};

    for (final raw in text.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final matches = _email.allMatches(line).toList();
      if (matches.isEmpty) {
        rejected.add(line);
        continue;
      }

      String? first;
      String? last;
      if (matches.length == 1) {
        final rest = line
            .replaceRange(matches.single.start, matches.single.end, ' ')
            .replaceAll(_nameNoise, ' ')
            .trim()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();
        if (rest.isNotEmpty) {
          first = _clip(rest.first);
          last = rest.length > 1 ? _clip(rest.skip(1).join(' ')) : null;
        }
      }

      for (final match in matches) {
        final email = match.group(0)!.trim();
        if (!seen.add(email.toLowerCase())) continue;
        entries.add(
          ContactImportEntry(email: email, firstName: first, lastName: last),
        );
      }
    }

    return ContactImportDraft(entries: entries, rejected: rejected);
  }

  /// The server takes names of up to `Contact.maxNameLength` characters and
  /// refuses the whole batch over a longer one.
  static String _clip(String name) => name.length <= Contact.maxNameLength
      ? name
      : name.substring(0, Contact.maxNameLength).trim();
}

/// Adds up the results of several import requests into one.
ContactImportResult mergeImportResults(
  ContactImportResult a,
  ContactImportResult b,
) {
  return ContactImportResult(
    status:
        a.status == ContactImportStatus.queued ||
            b.status == ContactImportStatus.queued
        ? ContactImportStatus.queued
        : ContactImportStatus.done,
    accepted: a.accepted + b.accepted,
    matched: a.matched + b.matched,
    pending: a.pending + b.pending,
    invalid: a.invalid + b.invalid,
    contacts: [...a.contacts, ...b.contacts],
  );
}
