import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/project/domain/entities/project_entity.dart';
import 'package:chatix/features/project/presentation/providers/my_projects_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_list_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

/// `POST /projects/` 🔒 (api-docs §5.1). Note the long text field is labelled
/// "Description" but is sent as the `description` request key (it comes back
/// as `full_description` on read — the data layer handles that asymmetry).
class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _slug = TextEditingController();
  final _small = TextEditingController();
  final _description = TextEditingController();
  final _tags = TextEditingController();
  ProjectVisibility _visibility = ProjectVisibility.public;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _slug.dispose();
    _small.dispose();
    _description.dispose();
    _tags.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final tags = _tags.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    // Pre-flight against the per-user limit if we already know the count.
    final knownCount = ref.read(myProjectsProvider).value?.total;

    final result = await ref.read(createProjectUseCaseProvider).execute(
          name: _name.text.trim(),
          slug: _slug.text.trim(),
          smallDescription: _small.text.trim().isEmpty ? null : _small.text.trim(),
          description: _description.text.trim().isEmpty ? null : _description.text.trim(),
          visibility: _visibility,
          tags: tags.isEmpty ? null : tags,
          currentProjectCount: knownCount,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendly(failure))),
      ),
      (_) {
        // Refresh the lists so the new project shows up immediately.
        ref.invalidate(myProjectsProvider);
        ref.read(projectListProvider.notifier).refresh();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Project created')));
        Navigator.of(context).pop();
      },
    );
  }

  /// Turns the documented project error codes (api-docs §5.1) into friendly
  /// copy; falls back to the raw message otherwise.
  String _friendly(Failure failure) {
    if (failure is ApiFailure) {
      switch (failure.code) {
        case 'MAX_PROJECTS_LIMIT_EXCEEDED':
          return 'You have reached the maximum number of projects.';
        case 'ALREADY_EXISTS':
          return 'That slug is already taken — choose another.';
        case 'TOO_LONG_NAME':
          return 'Project name is too long (max 200 characters).';
        case 'TOO_LONG_TAG_NAME':
          return 'One of the tags is too long (max 50 characters).';
      }
    }
    return failure.message;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Name *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _slug,
              maxLength: 210,
              decoration: const InputDecoration(
                labelText: 'Slug *',
                helperText: 'Unique, immutable after creation',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Slug is required' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _small,
              decoration: const InputDecoration(
                labelText: 'Short description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ProjectVisibility>(
              initialValue: _visibility,
              decoration: const InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(),
              ),
              items: ProjectVisibility.values
                  .map((v) => DropdownMenuItem(
                        value: v,
                        child: Text(projectVisibilityLabel(v)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _visibility = v ?? _visibility),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tags,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create project'),
            ),
          ],
        ),
      ),
    );
  }
}
