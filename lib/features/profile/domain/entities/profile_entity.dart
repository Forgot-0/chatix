import 'package:equatable/equatable.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';

/// `ProfileDTO` (api-docs §4.3). `id` is always equal to the owning
/// `user_id` (1:1 relation, api-docs §4.1) — there's no separate profile id.
class ProfileEntity extends Equatable {
  final int id;

  /// `avatars["32"|"64"|"256"|"512"]["jpg"|"webp"|"avif"] -> url`. Empty
  /// map `{}` means the user has no avatar yet (api-docs §4.3) — this is
  /// the normal state for a freshly-registered profile, not an error.
  final Map<String, Map<String, String>> avatars;
  final String? specialization;
  final String? displayName;
  final String? bio;

  /// Date-only (`YYYY-MM-DD` on the wire, api-docs §4.3) — time-of-day is
  /// never meaningful here, but `DateTime` is still the right domain type
  /// since it composes with `FormBuilderDateTimePicker` and date math
  /// without a separate value type.
  final DateTime? dateBirthday;

  /// Kept as an ordered `List<String>` rather than a `Set<String>`: the
  /// wire format is a plain JSON array (the backend's Python `set` is
  /// already flattened to a list server-side, api-docs §4.3) and a `List`
  /// keeps deserialization straightforward and UI ordering (skill chips)
  /// stable, at the cost of not enforcing uniqueness client-side — the
  /// server already lowercases and is the source of truth for duplicates.
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

  /// Picks the avatar URL closest to [preferredSize] (one of 32/64/256/512,
  /// though this tolerates whatever numeric size keys are actually
  /// present) so profile widgets don't each re-implement this lookup.
  ///
  /// Size preference: the smallest available size that's still `>=
  /// preferredSize` (avoids visibly upscaling/blurring a smaller image),
  /// falling back to the largest available size below it if nothing bigger
  /// exists.
  ///
  /// Format preference within a chosen size: `webp` → `jpg` → `avif`.
  /// `webp` has the best size/quality tradeoff with broad support; `jpg` is
  /// the universal fallback; `avif` is listed last because Flutter's image
  /// stack (and `cached_network_image`) doesn't reliably decode AVIF on
  /// every platform yet, whereas the other two always render.
  ///
  /// Returns `null` when [avatars] is empty (no avatar uploaded) or, in the
  /// unexpected case, contains sizes/formats that don't resolve to any URL.
  String? bestAvatarUrl(int preferredSize) {
    if (avatars.isEmpty) return null;

    final availableSizes = avatars.keys.map(int.tryParse).whereType<int>().toList()..sort();
    if (availableSizes.isEmpty) return null;

    final atLeastPreferred = availableSizes.where((size) => size >= preferredSize);
    final smallerThanPreferred = availableSizes.where((size) => size < preferredSize).toList().reversed;
    final orderedSizes = [...atLeastPreferred, ...smallerThanPreferred];

    const formatPriority = ['webp', 'jpg', 'avif'];

    for (final size in orderedSizes) {
      final formats = avatars[size.toString()];
      if (formats == null || formats.isEmpty) continue;

      for (final format in formatPriority) {
        final url = formats[format];
        if (url != null && url.isNotEmpty) return url;
      }

      // This size has data under a format key we didn't anticipate —
      // still better to use it than to skip a perfectly good image.
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
