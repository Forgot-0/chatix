import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_update.dart';
import 'package:chatix/features/profile/domain/usecases/update_profile_use_case.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/providers/profile_edit_provider.dart';
import 'package:chatix/features/profile/presentation/utils/profile_contact_link.dart';
import 'package:chatix/features/profile/presentation/utils/profile_field_validators.dart';
import 'package:chatix/features/profile/presentation/widgets/skills_chips_field.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Editing one's own profile.
///
/// The form always submits every field, never only the ones that changed:
/// `PUT /profiles/{id}/` assigns the request body onto the row as it stands,
/// so a field left out of the request is set to `null` rather than kept
/// (api-docs §4.4). That is why [_values] builds a complete [ProfileUpdate]
/// out of the form rather than a diff.
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  static const String _displayNameField = 'displayName';
  static const String _specializationField = 'specialization';
  static const String _bioField = 'bio';
  static const String _birthdayField = 'dateBirthday';
  static const String _skillsField = 'skills';

  final _formKey = GlobalKey<FormBuilderState>();

  /// What the profile looked like when the form opened, so "has anything
  /// changed?" has an answer that survives the links being saved underneath
  /// it.
  ProfileUpdate? _opened;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currentUserId = ref.watch(
      authProvider.select((user) => user.value?.id),
    );

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.editProfile)),
        body: Center(child: Text(l10n.signInToEditProfile)),
      );
    }

    final profileAsync = ref.watch(profileDetailProvider(currentUserId));
    final editState = ref.watch(profileEditProvider);

    ref.listen(profileEditProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        AppSnackbar.quiet(
          context,
          friendlyFailureMessage(next.error, fallback: l10n.saveChangesFailed),
        );
      }
    });

    return PopScope(
      canPop: !_isDirty(),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;

        final discard = await _confirmDiscard();
        if (!discard || !mounted) return;
        if (context.mounted) context.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.editProfile),
          actions: [
            TextButton(
              onPressed: editState.isLoading
                  ? null
                  : () => _submit(currentUserId),
              child: Text(l10n.save),
            ),
          ],
        ),
        body: profileAsync.when(
          loading: () => const AppListSkeleton(),
          error: (error, _) => AppErrorState(
            error: error,
            fallbackMessage: l10n.myProfileLoadFailed,
            retryLabel: l10n.retry,
            onRetry: () => ref.invalidate(profileDetailProvider(currentUserId)),
          ),
          data: (profile) {
            _opened ??= ProfileUpdate.of(profile);
            return _form(l10n, profile, isSubmitting: editState.isLoading);
          },
        ),
      ),
    );
  }

  Widget _form(
    AppLocalizations l10n,
    ProfileEntity profile, {
    required bool isSubmitting,
  }) {
    final theme = Theme.of(context);
    final opened = _opened!;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: FormBuilder(
        key: _formKey,
        onChanged: () => setState(() {}),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.profileEditDetails, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),

            FormBuilderTextField(
              name: _displayNameField,
              initialValue: opened.displayName,
              textInputAction: TextInputAction.next,
              maxLength: UpdateProfileUseCase.maxDisplayNameLength,
              decoration: InputDecoration(
                labelText: l10n.displayName,
                border: const OutlineInputBorder(),
              ),
              validator: ProfileFieldValidators.displayName(l10n),
            ),
            const SizedBox(height: 12),

            FormBuilderTextField(
              name: _specializationField,
              initialValue: opened.specialization,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l10n.specialization,
                helperText: l10n.specializationHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            FormBuilderTextField(
              name: _bioField,
              initialValue: opened.bio,
              maxLines: 5,
              maxLength: UpdateProfileUseCase.maxBioLength,
              decoration: InputDecoration(
                labelText: l10n.bio,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
              validator: ProfileFieldValidators.bio(l10n),
            ),
            const SizedBox(height: 12),

            FormBuilderDateTimePicker(
              name: _birthdayField,
              inputType: InputType.date,
              initialValue: opened.dateBirthday,
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
              decoration: InputDecoration(
                labelText: l10n.dateOfBirth,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: l10n.clearDateOfBirth,
                  icon: const Icon(Icons.clear),
                  // Clearing has to reach the server as an explicit null,
                  // which is exactly what a full-set PUT sends (§4.4).
                  onPressed: () => _formKey.currentState?.fields[_birthdayField]
                      ?.didChange(null),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SkillsChipsField(
              name: _skillsField,
              initialValue: opened.skills,
              validator: ProfileFieldValidators.skills(l10n),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(
                l10n.profileSkillsHint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 24),
            FilledButton(
              onPressed: isSubmitting ? null : () => _submit(profile.id),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.save),
            ),

            const SizedBox(height: 32),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Text(l10n.profileEditLinks, style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              // Links are their own endpoints — `POST`/`DELETE
              // /profiles/{id}/links/` (api-docs §4.6) — so they take effect
              // at once and are not part of the save above.
              l10n.profileEditLinksHint,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),

            if (profile.contacts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l10n.profileNoLinks,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final contact in profile.contacts)
                _LinkTile(
                  contact: contact,
                  onRemove: () => _removeLink(profile.id, contact),
                ),

            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _addLink(profile.id),
                icon: const Icon(Icons.add),
                label: Text(l10n.addContact),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The whole editable profile as the form currently has it.
  ///
  /// Blank text fields become `null` rather than `""`: the server stores
  /// whatever it is given, and an empty string would read as "has a bio" on
  /// every screen that checks.
  ProfileUpdate _values() {
    final state = _formKey.currentState;
    final values = state?.value ?? const <String, dynamic>{};

    return ProfileUpdate(
      specialization: _text(values[_specializationField]),
      displayName: _text(values[_displayNameField]),
      bio: _text(values[_bioField]),
      skills: (values[_skillsField] as List?)?.cast<String>() ?? const [],
      dateBirthday: values[_birthdayField] as DateTime?,
    );
  }

  static String? _text(Object? value) {
    final trimmed = (value as String?)?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  bool _isDirty() {
    final opened = _opened;
    if (opened == null || _formKey.currentState == null) return false;
    return _values() != opened;
  }

  Future<bool> _confirmDiscard() async {
    final l10n = AppLocalizations.of(context);

    final discard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.keepEditingAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.discardAction),
          ),
        ],
      ),
    );

    return discard ?? false;
  }

  Future<void> _submit(int profileId) async {
    final l10n = AppLocalizations.of(context);

    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final update = _values();
    final saved = await ref
        .read(profileEditProvider.notifier)
        .submit(profileId, update);

    if (!saved || !mounted) return;

    setState(() => _opened = update);
    AppSnackbar.quiet(context, l10n.profileSaved);
    if (context.canPop()) context.pop();
  }

  Future<void> _addLink(int profileId) async {
    final l10n = AppLocalizations.of(context);
    final link = await _askForLink();
    if (link == null || !mounted) return;

    final added = await ref
        .read(profileEditProvider.notifier)
        .addContact(profileId, provider: link.provider, contact: link.contact);

    if (added || !mounted) return;
    AppSnackbar.quiet(context, l10n.saveChangesFailed);
  }

  Future<void> _removeLink(int profileId, ContactEntity contact) async {
    final l10n = AppLocalizations.of(context);

    final removed = await ref
        .read(profileEditProvider.notifier)
        .removeContact(profileId, provider: contact.provider);

    if (removed || !mounted) return;
    AppSnackbar.quiet(context, l10n.saveChangesFailed);
  }

  Future<({String provider, String contact})?> _askForLink() {
    return showDialog<({String provider, String contact})>(
      context: context,
      builder: (dialogContext) => const _AddLinkDialog(),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.contact, required this.onRemove});

  final ContactEntity contact;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final link = profileContactLinkOf(contact);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        link.icon,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(link.value, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(link.label),
      trailing: IconButton(
        tooltip: l10n.removeLink,
        icon: const Icon(Icons.delete_outline),
        onPressed: onRemove,
      ),
    );
  }
}

/// Asks for one `provider`/`contact` pair.
///
/// Its own widget so the two controllers live and die with the dialog; a
/// builder closure would leak them every time the dialog was dismissed by
/// tapping outside.
class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _provider = TextEditingController();
  final _contact = TextEditingController();

  @override
  void dispose() {
    _provider.dispose();
    _contact.dispose();
    super.dispose();
  }

  bool get _isComplete =>
      _provider.text.trim().isNotEmpty && _contact.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.addContact),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _provider,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.contactProvider),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contact,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: l10n.contactHandle),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _isComplete
              ? () => Navigator.of(context).pop((
                  // The server overwrites by provider, so it is stored
                  // lower-cased to keep "Telegram" and "telegram" from
                  // becoming two rows (api-docs §4.6).
                  provider: _provider.text.trim().toLowerCase(),
                  contact: _contact.text.trim(),
                ))
              : null,
          child: Text(l10n.add),
        ),
      ],
    );
  }
}
