import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/project/data/models/project_member_model.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';

part 'project_model.g.dart';

/// `ProjectDTO` (api-docs §5.1).
///
/// ⚠️ Wire-naming asymmetry: on **read** the long text field arrives as
/// `full_description` (mapped here to [fullDescription]); on **write**
/// (`ProjectCreateRequest`/`ProjectUpdateRequest`) the very same field must be
/// sent as `description`. This model only ever deserializes *responses*, so it
/// reads `full_description`; the request side is built by hand in
/// `ProjectRemoteDataSource` (which is where the `description` key is emitted,
/// with a matching comment).
///
/// [visibility] is kept as the raw wire string and converted to
/// [ProjectVisibility] in [toEntity]; date fields likewise stay as raw
/// strings until the entity boundary (mirrors `ProfileModel`).
@JsonSerializable(fieldRename: FieldRename.snake)
class ProjectModel extends Equatable {
  final int id;
  final int ownerId;
  final String name;
  final String slug;
  final String? smallDescription;
  final String? fullDescription;
  final String visibility;
  @JsonKey(defaultValue: {})
  final Map<String, dynamic> metaData;
  @JsonKey(defaultValue: [])
  final List<String> tags;
  final String? createdAt;
  final String? updatedAt;
  @JsonKey(defaultValue: [])
  final List<ProjectMemberModel> memberships;

  const ProjectModel({
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

  factory ProjectModel.fromJson(Map<String, dynamic> json) => _$ProjectModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectModelToJson(this);
}

extension ProjectModelX on ProjectModel {
  ProjectEntity toEntity() {
    return ProjectEntity(
      id: id,
      ownerId: ownerId,
      name: name,
      slug: slug,
      smallDescription: smallDescription,
      fullDescription: fullDescription,
      visibility: ProjectVisibility.fromWire(visibility),
      metaData: metaData,
      tags: tags,
      createdAt: createdAt != null ? DateTime.parse(createdAt!) : null,
      updatedAt: updatedAt != null ? DateTime.parse(updatedAt!) : null,
      memberships: memberships.map((m) => m.toEntity()).toList(),
    );
  }
}
