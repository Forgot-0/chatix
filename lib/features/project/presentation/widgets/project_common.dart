import 'package:flutter/material.dart';
import 'package:chatix/features/project/domain/entities/application_entity.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';

/// Shared, reusable pieces for the project screens — a standard error/retry
/// view and human-readable labels for the various wire enums, so each screen
/// doesn't re-implement the same `switch`.

class ProjectErrorView extends StatelessWidget {
  const ProjectErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(message, textAlign: TextAlign.center),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}

String projectVisibilityLabel(ProjectVisibility v) => switch (v) {
      ProjectVisibility.private => 'Private',
      ProjectVisibility.internal => 'Internal',
      ProjectVisibility.public => 'Public',
    };

String memberStatusLabel(ProjectMemberStatus s) => switch (s) {
      ProjectMemberStatus.invited => 'Invited',
      ProjectMemberStatus.pending => 'Pending',
      ProjectMemberStatus.active => 'Active',
      ProjectMemberStatus.suspended => 'Suspended',
      ProjectMemberStatus.removed => 'Removed',
    };

String locationTypeLabel(PositionLocationType t) => switch (t) {
      PositionLocationType.remote => 'Remote',
      PositionLocationType.onsite => 'On-site',
      PositionLocationType.hybrid => 'Hybrid',
    };

String expectedLoadLabel(PositionExpectedLoad l) => switch (l) {
      PositionExpectedLoad.low => 'Low',
      PositionExpectedLoad.medium => 'Medium',
      PositionExpectedLoad.high => 'High',
    };

String applicationStatusLabel(ApplicationStatus s) => switch (s) {
      ApplicationStatus.pending => 'Pending',
      ApplicationStatus.accepted => 'Accepted',
      ApplicationStatus.rejected => 'Rejected',
    };

Color applicationStatusColor(ApplicationStatus s) => switch (s) {
      ApplicationStatus.pending => Colors.orange,
      ApplicationStatus.accepted => Colors.green,
      ApplicationStatus.rejected => Colors.red,
    };
