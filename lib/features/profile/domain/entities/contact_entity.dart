import 'package:equatable/equatable.dart';

/// `ContactDTO` (api-docs §4.3): `{ profile_id, provider, contact }`.
///
/// A profile can list e.g. `provider: "telegram", contact: "@handle"` —
/// the backend treats both as free-form strings, no enum of known
/// providers is documented.
class ContactEntity extends Equatable {
  final int profileId;
  final String provider;
  final String contact;

  const ContactEntity({
    required this.profileId,
    required this.provider,
    required this.contact,
  });

  @override
  List<Object?> get props => [profileId, provider, contact];
}
