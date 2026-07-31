import 'package:equatable/equatable.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';

/// Project visibility (api-docs §5.1). ⚠️ Three values, not two —
/// `internal` sits between `private` and `public`. Defaults to `public`
/// server-side when omitted on create.
enum ProjectVisibility {
  private,
  internal,
  public;

  /// Wire value (identical to the enum name, but centralised here so
  /// callers never hand-type the string).
  String get wire => name;

  /// Parses the server string, defaulting to [ProjectVisibility.public]
  /// (the backend's own default) for anything unrecognised rather than
  /// throwing on an unexpected value.
  static ProjectVisibility fromWire(String? value) {
    return ProjectVisibility.values.firstWhere(
      (v) => v.name == value,
      orElse: () => ProjectVisibility.public,
    );
  }
}

/// `ProjectDTO` (api-docs §5.1).
class ProjectEntity extends Equatable {
  final int id;
  final int ownerId;
  final String name;
  final String slug;
  final String? smallDescription;

  /// ⚠️ NAMING TRAP (api-docs §5.1): this single logical field is called
  /// **`description`** in the *request* bodies (`ProjectCreateRequest` /
  /// `ProjectUpdateRequest`) but comes back as **`full_description`** in the
  /// *response* (`ProjectDTO`). We expose it here under one consistent
  /// domain name, [fullDescription]; the asymmetric wire mapping is handled
  /// (and commented) in `ProjectModel` / `ProjectRemoteDataSource`.
  final String? fullDescription;

  final ProjectVisibility visibility;
  final Map<String, dynamic> metaData;
  final List<String> tags;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// The project's members, embedded directly in the `ProjectDTO` response
  /// (api-docs §5.1). Empty when the caller can't see memberships or the
  /// project has none.
  final List<ProjectMemberEntity> memberships;

  const ProjectEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.slug,
    required this.smallDescription,
    required this.fullDescription,
    required this.visibility,
    required this.metaData,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.memberships,
  });

  /// The membership row for [userId], or `null` if that user isn't a member
  /// of this project. Handy for resolving "me" so the UI can gate buttons
  /// via `hasProjectPermission` (api-docs §10.6).
  ProjectMemberEntity? membershipOf(int userId) {
    for (final m in memberships) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  ProjectEntity copyWith({
    int? id,
    int? ownerId,
    String? name,
    String? slug,
    String? smallDescription,
    String? fullDescription,
    ProjectVisibility? visibility,
    Map<String, dynamic>? metaData,
    List<String>? tags,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ProjectMemberEntity>? memberships,
  }) {
    return ProjectEntity(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      smallDescription: smallDescription ?? this.smallDescription,
      fullDescription: fullDescription ?? this.fullDescription,
      visibility: visibility ?? this.visibility,
      metaData: metaData ?? this.metaData,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      memberships: memberships ?? this.memberships,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    name,
    slug,
    smallDescription,
    fullDescription,
    visibility,
    metaData,
    tags,
    createdAt,
    updatedAt,
    memberships,
  ];
}
