import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_edit_provider.dart';
import 'package:chatix/features/profile/presentation/utils/profile_field_validators.dart';
import 'package:chatix/features/profile/presentation/widgets/skills_chips_field.dart';
import 'package:chatix/core/error/failure_messages.dart';

/// Edits the signed-in person's own profile (api-docs §4.4/§4.6 — there's
/// no route/way to reach this screen for anyone else's profile, matching
/// the "no system-rights UI yet" note on `ProfileScreen`).
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _formKey = GlobalKey<FormBuilderState>();

  Future<void> _submit(int profileId) async {
    final isValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!isValid) return;

    FocusScope.of(context).unfocus();

    final values = _formKey.currentState!.value;
    // ⚠️ PUT overwrites: every field below must reflect the full current
    // state, not just what changed, per UpdateProfileUseCase's warning —
    // which is exactly what prefilling every field with the loaded
    // profile's current value (below, in _EditForm) guarantees.
    final success = await ref
        .read(profileEditProvider.notifier)
        .submit(
          profileId,
          specialization: values['specialization'] as String?,
          displayName: values['displayName'] as String?,
          bio: values['bio'] as String?,
          skills: (values['skills'] as List?)?.cast<String>() ?? const [],
          dateBirthday: values['dateBirthday'] as DateTime?,
        );

    if (success && mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).value?.id;

    if (currentUserId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to edit your profile')));
    }

    final profileAsync = ref.watch(profileDetailProvider(currentUserId));
    final editState = ref.watch(profileEditProvider);

    ref.listen(profileEditProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        final error = next.error;
        AppUtils.showSnackBar(
          context,
          message: friendlyFailureMessage(error, fallback: 'Could not save changes'),
          backgroundColor: Theme.of(context).colorScheme.error,
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(friendlyFailureMessage(error, fallback: 'Could not load your profile'))),
        data: (profile) => _EditForm(
          formKey: _formKey,
          profile: profile,
          isSubmitting: editState.isLoading,
          onSubmit: () => _submit(profile.id),
        ),
      ),
    );
  }
}

class _EditForm extends ConsumerWidget {
  final GlobalKey<FormBuilderState> formKey;
  final ProfileEntity profile;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  const _EditForm({
    required this.formKey,
    required this.profile,
    required this.isSubmitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: FormBuilder(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormBuilderTextField(
              name: 'displayName',
              initialValue: profile.displayName,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: ProfileFieldValidators.displayName,
            ),
            const SizedBox(height: 16),
            FormBuilderTextField(
              name: 'specialization',
              initialValue: profile.specialization,
              decoration: const InputDecoration(labelText: 'Specialization'),
            ),
            const SizedBox(height: 16),
            FormBuilderTextField(
              name: 'bio',
              initialValue: profile.bio,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Bio', alignLabelWithHint: true),
              validator: ProfileFieldValidators.bio,
            ),
            const SizedBox(height: 16),
            FormBuilderDateTimePicker(
              name: 'dateBirthday',
              inputType: InputType.date,
              initialValue: profile.dateBirthday,
              decoration: const InputDecoration(labelText: 'Date of birth'),
            ),
            const SizedBox(height: 16),
            SkillsChipsField(
              name: 'skills',
              initialValue: profile.skills,
              validator: ProfileFieldValidators.skills,
            ),
            const SizedBox(height: 24),
            Text('Contacts', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildContacts(ref),
            TextButton.icon(
              onPressed: () => _showAddContactDialog(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add contact'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContacts(WidgetRef ref) {
    return profile.contacts
        .map(
          (contact) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: Text(contact.contact),
            subtitle: Text(contact.provider),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                ref.read(profileEditProvider.notifier).removeContact(profile.id, provider: contact.provider);
              },
            ),
          ),
        )
        .toList();
  }

  Future<void> _showAddContactDialog(BuildContext context, WidgetRef ref) async {
    final providerController = TextEditingController();
    final contactController = TextEditingController();

    final added = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: providerController,
              decoration: const InputDecoration(labelText: 'Provider (e.g. telegram)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(labelText: 'Contact (e.g. @handle)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Add')),
        ],
      ),
    );

    if (added == true) {
      await ref
          .read(profileEditProvider.notifier)
          .addContact(
            profile.id,
            provider: providerController.text.trim(),
            contact: contactController.text.trim(),
          );
    }

    providerController.dispose();
    contactController.dispose();
  }
}
