import 'package:equatable/equatable.dart';

/// Application decision status (api-docs §5.4). ⚠️ Distinct from
/// `ProjectMemberStatus` — this enum has only three values
/// (pending/accepted/rejected) and lives on `ApplicationDTO`, not on a
/// member. `pending` appears in both enums but is unrelated.
enum ApplicationStatus {
  pending,
  accepted,
  rejected;

  String get wire => name;

  static ApplicationStatus fromWire(String? value) {
    return ApplicationStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => ApplicationStatus.pending,
    );
  }
}

/// `ApplicationDTO` (api-docs §5.4). Both [id] and [positionId] are UUID
/// strings; [projectId] and [candidateId] are ints (api-docs §1.8).
class ApplicationEntity extends Equatable {
  final String id;
  final int projectId;
  final String positionId;
  final int candidateId;
  final ApplicationStatus status;
  final String? message;
  final int? decidedBy;
  final DateTime? decidedAt;

  const ApplicationEntity({
    required this.id,
    required this.projectId,
    required this.positionId,
    required this.candidateId,
    required this.status,
    required this.message,
    required this.decidedBy,
    required this.decidedAt,
  });

  bool get isPending => status == ApplicationStatus.pending;

  @override
  List<Object?> get props => [
    id,
    projectId,
    positionId,
    candidateId,
    status,
    message,
    decidedBy,
    decidedAt,
  ];
}
