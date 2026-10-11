import 'package:equatable/equatable.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';

/// One person `GET /contacts/search/` found — `ContactSearchItemDTO`
/// (api-docs §4.12).
class ContactSearchHit extends Equatable {
  const ContactSearchHit({required this.userId, this.profile, this.contact});

  final int userId;

  /// Null if the profile has been deleted.
  final ContactProfile? profile;

  /// Not null when the person is already in the book.
  final Contact? contact;

  bool get isContact => contact != null;

  @override
  List<Object?> get props => [userId, profile, contact];
}

/// The two ways `GET /contacts/search/` searches (api-docs §4.12).
abstract final class ContactSearchQuery {
  /// A non-`@` prefix shorter than this finds nothing on the server.
  static const int minPrefixLength = 2;

  static const int maxLength = 150;

  /// `@name` is an exact username lookup among everybody.
  static bool isUsername(String query) => query.trim().startsWith('@');

  /// The handle without its `@`s, for `/profiles/?q=` and local matching.
  static String stripAt(String query) =>
      query.trim().replaceFirst(RegExp(r'^@+'), '').trim();

  /// Whether the server would search [query] at all: an `@` and at least one
  /// character after it, or a prefix of [minPrefixLength] or more.
  static bool isSearchable(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty || trimmed.length > maxLength) return false;
    if (isUsername(trimmed)) return stripAt(trimmed).isNotEmpty;
    return trimmed.length >= minPrefixLength;
  }
}
