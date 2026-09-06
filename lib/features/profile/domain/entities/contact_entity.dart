import 'package:equatable/equatable.dart';

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
