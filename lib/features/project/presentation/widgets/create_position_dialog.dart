import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/position_entity.dart';
import 'package:chatix/features/project/presentation/providers/position_detail_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

/// `POST /projects/{id}/positions/` (api-docs §5.3). [currentOpenCount], when
/// known, lets the use case fail fast before the 5-open-positions limit
/// (`MAX_POSITIONS_PER_PROJECT_LIMIT_EXCEEDED`); the server is still the
/// final authority.
Future<void> showCreatePositionDialog(
  BuildContext context,
  WidgetRef ref, {
  required int projectId,
  int? currentOpenCount,
}) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final responsibilities = TextEditingController();
  final skills = TextEditingController();
  PositionLocationType location = PositionLocationType.remote;
  PositionExpectedLoad load = PositionExpectedLoad.medium;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('New position'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Title *'),
                  ),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description *'),
                  ),
                  TextField(
                    controller: responsibilities,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Responsibilities'),
                  ),
                  TextField(
                    controller: skills,
                    decoration: const InputDecoration(
                      labelText: 'Required skills (comma-separated)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PositionLocationType>(
                    initialValue: location,
                    decoration: const InputDecoration(labelText: 'Location type'),
                    items: PositionLocationType.values
                        .map((t) => DropdownMenuItem(value: t, child: Text(locationTypeLabel(t))))
                        .toList(),
                    onChanged: (v) => setState(() => location = v ?? location),
                  ),
                  DropdownButtonFormField<PositionExpectedLoad>(
                    initialValue: load,
                    decoration: const InputDecoration(labelText: 'Expected load'),
                    items: PositionExpectedLoad.values
                        .map((l) => DropdownMenuItem(value: l, child: Text(expectedLoadLabel(l))))
                        .toList(),
                    onChanged: (v) => setState(() => load = v ?? load),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final skillList = skills.text
                      .split(',')
                      .map((s) => s.trim())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  final result = await ref.read(createPositionUseCaseProvider).execute(
                        projectId,
                        title: title.text.trim(),
                        description: description.text.trim(),
                        responsibilities: responsibilities.text.trim().isEmpty
                            ? null
                            : responsibilities.text.trim(),
                        requiredSkills: skillList.isEmpty ? null : skillList,
                        locationType: location,
                        expectedLoad: load,
                        currentOpenPositionCount: currentOpenCount,
                      );
                  if (!dialogContext.mounted) return;
                  result.fold(
                    (f) => ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(SnackBar(content: Text(_friendly(f)))),
                    (_) {
                      ref.invalidate(projectPositionsProvider(projectId));
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('Position created')));
                    },
                  );
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      );
    },
  );
}

String _friendly(Failure failure) {
  if (failure is ApiFailure &&
      failure.code == 'MAX_POSITIONS_PER_PROJECT_LIMIT_EXCEEDED') {
    return 'This project already has the maximum number of open positions.';
  }
  return failure.message;
}
