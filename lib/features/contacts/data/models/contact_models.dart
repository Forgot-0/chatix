import 'package:chatix/features/contacts/domain/entities/blocked_user.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/domain/entities/contact_search.dart';
import 'package:chatix/features/contacts/domain/entities/contact_sync.dart';

/// The `/contacts` DTOs (api-docs §4.7–4.13) to and from JSON.
///
/// Written by hand rather than generated: the shapes are small, several
/// fields are nullable in ways a generator would make strict, and the same
/// wire form doubles as the on-device cache format — a row read from disk
/// goes through exactly the code a row from the network does.
abstract final class ContactJson {
  static Contact contact(Map<String, dynamic> json) {
    final profile = json['profile'];
    return Contact(
      ownerId: _int(json['owner_id']) ?? 0,
      userId: _int(json['contact_id']) ?? 0,
      firstName: _string(json['first_name']),
      lastName: _string(json['last_name']),
      source: ContactSource.fromWire(_int(json['source'])),
      isMutual: json['is_mutual'] == true,
      isFavorite: json['is_favorite'] == true,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      profile: profile is Map ? contactProfile(profile.cast()) : null,
    );
  }

  static Map<String, dynamic> contactToJson(Contact contact) => {
    'owner_id': contact.ownerId,
    'contact_id': contact.userId,
    'first_name': contact.firstName,
    'last_name': contact.lastName,
    'source': contact.source.wire,
    'is_mutual': contact.isMutual,
    'is_favorite': contact.isFavorite,
    'created_at': contact.createdAt.toUtc().toIso8601String(),
    'updated_at': contact.updatedAt.toUtc().toIso8601String(),
    'profile': switch (contact.profile) {
      final profile? => contactProfileToJson(profile),
      null => null,
    },
  };

  static ContactProfile contactProfile(Map<String, dynamic> json) {
    return ContactProfile(
      id: _int(json['id']) ?? 0,
      username: _string(json['username']),
      displayName: _string(json['display_name']),
      avatars: avatars(json['avatars']),
    );
  }

  static Map<String, dynamic> contactProfileToJson(ContactProfile profile) => {
    'id': profile.id,
    'username': profile.username,
    'display_name': profile.displayName,
    'avatars': profile.avatars,
  };

  /// `{ size: { format: url } }`, skipping anything that is not that shape.
  static Map<String, Map<String, String>> avatars(Object? raw) {
    if (raw is! Map) return const <String, Map<String, String>>{};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is Map)
          entry.key as String: {
            for (final format in (entry.value as Map).entries)
              if (format.key is String && format.value is String)
                format.key as String: format.value as String,
          },
    };
  }

  /// `ContactListDTO` (api-docs §4.8).
  static ContactPage page(Map<String, dynamic> json) {
    final raw = json['contacts'];
    return ContactPage(
      contacts: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) contact(item.cast()),
      ],
      hasNext: json['has_next'] == true,
      nextContactId: _int(json['next_contact_id']),
      version: _string(json['version']),
    );
  }

  /// `ContactSearchDTO` (api-docs §4.12).
  static List<ContactSearchHit> searchHits(Map<String, dynamic> json) {
    final raw = json['items'];
    if (raw is! List) return const <ContactSearchHit>[];

    return [
      for (final item in raw)
        if (item is Map)
          ContactSearchHit(
            userId: _int(item['user_id']) ?? 0,
            profile: item['profile'] is Map
                ? contactProfile((item['profile'] as Map).cast())
                : null,
            contact: item['contact'] is Map
                ? contact((item['contact'] as Map).cast())
                : null,
          ),
    ];
  }

  /// `BlockedListDTO` (api-docs §4.13).
  static BlockedPage blockedPage(Map<String, dynamic> json) {
    final raw = json['blocked'];
    return BlockedPage(
      users: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) blockedUser(item.cast()),
      ],
      hasNext: json['has_next'] == true,
      nextTargetId: _int(json['next_target_id']),
    );
  }

  static BlockedUser blockedUser(Map<String, dynamic> json) {
    final profile = json['profile'];
    return BlockedUser(
      userId: _int(json['target_id']) ?? 0,
      since: _date(json['created_at']),
      profile: profile is Map ? contactProfile(profile.cast()) : null,
    );
  }

  static Map<String, dynamic> importRequest(List<ContactImportEntry> entries) =>
      {
        'contacts': [
          for (final entry in entries)
            {
              'email': entry.email,
              'first_name': ?entry.firstName,
              'last_name': ?entry.lastName,
            },
        ],
      };

  /// `ImportContactsResultDTO` (api-docs §4.11).
  static ContactImportResult importResult(Map<String, dynamic> json) {
    final raw = json['contacts'];
    return ContactImportResult(
      status: json['status'] == 'queued'
          ? ContactImportStatus.queued
          : ContactImportStatus.done,
      accepted: _int(json['accepted']) ?? 0,
      matched: _int(json['matched']) ?? 0,
      pending: _int(json['pending']) ?? 0,
      invalid: _int(json['invalid']) ?? 0,
      contacts: [
        if (raw is List)
          for (final item in raw)
            if (item is Map) contact(item.cast()),
      ],
    );
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num && value == value.roundToDouble()) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _string(Object? value) => value is String ? value : null;

  static DateTime _date(Object? value) {
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }
}
