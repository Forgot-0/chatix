import 'package:equatable/equatable.dart';

/// Work arrangement of a position (api-docs §5.3).
enum PositionLocationType {
  remote,
  onsite,
  hybrid;

  String get wire => name;

  static PositionLocationType fromWire(String? value) {
    return PositionLocationType.values.firstWhere(
      (v) => v.name == value,
      orElse: () => PositionLocationType.remote,
    );
  }
}

/// Expected time commitment of a position (api-docs §5.3).
enum PositionExpectedLoad {
  low,
  medium,
  high;

  String get wire => name;

  static PositionExpectedLoad fromWire(String? value) {
    return PositionExpectedLoad.values.firstWhere(
      (v) => v.name == value,
      orElse: () => PositionExpectedLoad.medium,
    );
  }
}

/// `PositionDTO` (api-docs §5.3). ⚠️ [id] is a **UUID string** (unlike the
/// integer `projectId`) — positions and applications use UUIDs, projects and
/// members use ints (api-docs §1.8).
class PositionEntity extends Equatable {
  final String id;
  final int projectId;
  final String title;
  final String description;
  final String? responsibilities;
  final List<String> requiredSkills;
  final bool isOpen;
  final PositionLocationType locationType;
  final PositionExpectedLoad expectedLoad;

  const PositionEntity({
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
}
