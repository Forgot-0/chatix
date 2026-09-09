import 'package:equatable/equatable.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';

class ProfileEntity extends Equatable {
  final int id;

  final Map<String, Map<String, String>> avatars;
  final String? specialization;
  final String? displayName;
  final String? bio;

  final DateTime? dateBirthday;

  final List<String> skills;
  final List<ContactEntity> contacts;

  const ProfileEntity({
    required this.id,
    required this.avatars,
    required this.specialization,
    required this.displayName,
    required this.bio,
    required this.dateBirthday,
    required this.skills,
    required this.contacts,
  });

  bool get hasAvatar => avatars.isNotEmpty;

  String? bestAvatarUrl(int preferredSize) {
    if (avatars.isEmpty) return null;

    final availableSizes =
        avatars.keys.map(int.tryParse).whereType<int>().toList()..sort();
    if (availableSizes.isEmpty) return null;

    final atLeastPreferred = availableSizes.where(
      (size) => size >= preferredSize,
    );
    final smallerThanPreferred = availableSizes
        .where((size) => size < preferredSize)
        .toList()
        .reversed;
    final orderedSizes = [...atLeastPreferred, ...smallerThanPreferred];

    const formatPriority = ['webp', 'jpg', 'avif'];

    for (final size in orderedSizes) {
      final formats = avatars[size.toString()];
      if (formats == null || formats.isEmpty) continue;

      for (final format in formatPriority) {
        final url = formats[format];
        if (url != null && url.isNotEmpty) return url;
      }

      for (final url in formats.values) {
        if (url.isNotEmpty) return url;
      }
    }

    return null;
  }

  ProfileEntity copyWith({
    int? id,
    Map<String, Map<String, String>>? avatars,
    String? specialization,
    String? displayName,
    String? bio,
    DateTime? dateBirthday,
    List<String>? skills,
    List<ContactEntity>? contacts,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      avatars: avatars ?? this.avatars,
      specialization: specialization ?? this.specialization,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      dateBirthday: dateBirthday ?? this.dateBirthday,
      skills: skills ?? this.skills,
      contacts: contacts ?? this.contacts,
    );
  }

  @override
  List<Object?> get props => [
    id,
    avatars,
    specialization,
    displayName,
    bio,
    dateBirthday,
    skills,
    contacts,
  ];
}
