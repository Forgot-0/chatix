import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';

part 'position_model.g.dart';

/// `PositionDTO` (api-docs §5.3). [id] is a UUID string; [projectId] is an
/// int. [locationType]/[expectedLoad] stay as raw wire strings and are mapped
/// to enums in [toEntity].
@JsonSerializable(fieldRename: FieldRename.snake)
class PositionModel extends Equatable {
  final String id;
  final int projectId;
  final String title;
  final String description;
  final String? responsibilities;
  @JsonKey(defaultValue: [])
  final List<String> requiredSkills;
  final bool isOpen;
  final String locationType;
  final String expectedLoad;

  const PositionModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.description,
    required this.responsibilities,
    required this.requiredSkills,
    required this.isOpen,
    required this.locationType,
    required this.expectedLoad,
  });

  @override
  List<Object?> get props => [
    id,
    projectId,
    title,
    description,
    responsibilities,
    requiredSkills,
    isOpen,
    locationType,
    expectedLoad,
  ];

  factory PositionModel.fromJson(Map<String, dynamic> json) => _$PositionModelFromJson(json);

  Map<String, dynamic> toJson() => _$PositionModelToJson(this);
}

extension PositionModelX on PositionModel {
  PositionEntity toEntity() {
    return PositionEntity(
      id: id,
      projectId: projectId,
      title: title,
      description: description,
      responsibilities: responsibilities,
      requiredSkills: requiredSkills,
      isOpen: isOpen,
      locationType: PositionLocationType.fromWire(locationType),
      expectedLoad: PositionExpectedLoad.fromWire(expectedLoad),
    );
  }
}
