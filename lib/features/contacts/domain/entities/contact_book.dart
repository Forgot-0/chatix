import 'package:equatable/equatable.dart';

import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_collation.dart';

/// The address book as a lookup: who is in it, and under what name.
class ContactBook extends Equatable {
  ContactBook(Iterable<Contact> contacts)
    : _byId = Map.unmodifiable({
        for (final contact in contacts) contact.userId: contact,
      });

  const ContactBook._(this._byId);

  static const ContactBook empty = ContactBook._(<int, Contact>{});

  final Map<int, Contact> _byId;

  bool get isEmpty => _byId.isEmpty;
  int get length => _byId.length;

  Iterable<Contact> get contacts => _byId.values;

  Contact? operator [](int userId) => _byId[userId];

  bool contains(int userId) => _byId.containsKey(userId);

  /// The name the owner gave [userId], or null when they gave none or the
  /// person is not in the book.
  String? localNameOf(int userId) => _byId[userId]?.localName;

  /// Favourites, in the same order as the full list.
  List<Contact> favorites({required String languageCode}) =>
      ContactCollation.sorted(
        contacts.where((contact) => contact.isFavorite),
        languageCode: languageCode,
      );

  List<ContactSection> sections({required String languageCode}) =>
      ContactCollation.sections(contacts, languageCode: languageCode);

  List<Contact> search(String query, {required String languageCode}) =>
      ContactMatcher.filter(contacts, query, languageCode: languageCode);

  @override
  List<Object?> get props => [_byId];
}
