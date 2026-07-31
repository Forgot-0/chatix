import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';

part 'project_role_model.g.dart';

/// `ProjectRoleDTO` (api-docs §5.5): `{ id, name, permissions }`.
@JsonSerializable(fieldRename: FieldRename.snake)
class ProjectRoleModel extends Equatable {
  final int id;
  final String name;
  final Map<String, bool> permissions;

  const ProjectRoleModel({
    required this.id,
    required this.name,
    required this.permissions,
  });

  @override
  List<Object?> get props => [id, name, permissions];

  factory ProjectRoleModel.fromJson(Map<String, dynamic> json) => _$ProjectRoleModelFromJson(json);

  Map<String, dynamic> toJson() => _$ProjectRoleModelToJson(this);
}

extension ProjectRoleModelX on ProjectRoleModel {
  ProjectRoleEntity toEntity() {
    return ProjectRoleEntity(id: id, name: name, permissions: permissions);
  }
}
