import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:uuid/uuid.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// "Add contact": an exact `@username` and, if wanted, a name only the owner
/// sees. Stays open on a refusal — "nobody has that username" is something
/// to correct, not to start over from. Answers with the new contact.
Future<Contact?> showAddContactDialog(
  BuildContext context, {
  String? initialUsername,
}) {
  return showDialog<Contact>(
    context: context,
    builder: (_) => _AddContactDialog(initialUsername: initialUsername),
  );
}

/// "Edit name": the contact's local name. Answers true once it is saved.
Future<bool> showRenameContactDialog(BuildContext context, Contact contact) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _RenameContactDialog(contact: contact),
  ).then((saved) => saved ?? false);
}

/// Asks before a contact leaves the book.
Future<bool> showDeleteContactDialog(BuildContext context, String name) {
  final l10n = AppLocalizations.of(context);

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: Text(l10n.contactsDeleteTitle(name)),
        content: Text(l10n.contactsDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.contactsActionDelete),
          ),
        ],
      );
    },
  ).then((confirmed) => confirmed ?? false);
}

/// "Import by email": paste addresses, see how many were recognised, send.
/// Answers with what the server made of them.
Future<ContactImportResult?> showImportContactsDialog(BuildContext context) {
  return showDialog<ContactImportResult>(
    context: context,
    builder: (_) => const _ImportContactsDialog(),
  );
}

/// The frame every contact dialog shares: a width that suits a form on a
/// desktop and still fits a phone, and a busy state that locks it.
class _ContactFormDialog extends StatelessWidget {
  const _ContactFormDialog({
    required this.title,
    required this.children,
    required this.submitLabel,
    required this.onSubmit,
    required this.isBusy,
    this.error,
  });

  final String title;
  final List<Widget> children;
  final String submitLabel;
  final VoidCallback? onSubmit;
  final bool isBusy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: AppDialogSizes.pickerMaxWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...children,
            if (error case final message?) ...[
              const SizedBox(height: AppSpacing.x3),
              Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isBusy ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: isBusy ? null : onSubmit,
          child: isBusy
              ? const SizedBox.square(
                  dimension: AppSpacing.x4,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(submitLabel),
        ),
      ],
    );
  }
}

class _NameFields extends StatelessWidget {
  const _NameFields({
    required this.first,
    required this.last,
    required this.enabled,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController first;
  final TextEditingController last;
  final bool enabled;
  final bool autofocus;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: first,
          enabled: enabled,
          autofocus: autofocus,
          maxLength: Contact.maxNameLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.contactsFirstName,
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        TextField(
          controller: last,
          enabled: enabled,
          maxLength: Contact.maxNameLength,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
          decoration: InputDecoration(
            labelText: l10n.contactsLastName,
            counterText: '',
          ),
        ),
      ],
    );
  }
}

class _AddContactDialog extends ConsumerStatefulWidget {
  const _AddContactDialog({this.initialUsername});

  final String? initialUsername;

  @override
  ConsumerState<_AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends ConsumerState<_AddContactDialog> {
  late final _username = TextEditingController(text: widget.initialUsername);
  final _first = TextEditingController();
  final _last = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final handle = _username.text.trim().replaceFirst(RegExp('^@+'), '');
    if (handle.isEmpty) {
      setState(() => _error = l10n.contactsUsernameRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(contactsProvider.notifier)
        .add(username: handle, firstName: _first.text, lastName: _last.text);
    if (!mounted) return;

    result.match(
      (failure) => setState(() {
        _busy = false;
        _error = contactFailureMessage(failure, l10n);
      }),
      (contact) => Navigator.of(context).pop(contact),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _ContactFormDialog(
      title: l10n.contactsAddAction,
      submitLabel: l10n.contactsAddSubmit,
      onSubmit: _submit,
      isBusy: _busy,
      error: _error,
      children: [
        Text(
          l10n.contactsAddExplain,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _username,
          enabled: !_busy,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: l10n.contactsUsernameLabel,
            prefixText: '@',
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        _NameFields(
          first: _first,
          last: _last,
          enabled: !_busy,
          onSubmitted: _submit,
        ),
      ],
    );
  }
}

class _RenameContactDialog extends ConsumerStatefulWidget {
  const _RenameContactDialog({required this.contact});

  final Contact contact;

  @override
  ConsumerState<_RenameContactDialog> createState() =>
      _RenameContactDialogState();
}

class _RenameContactDialogState extends ConsumerState<_RenameContactDialog> {
  late final _first = TextEditingController(text: widget.contact.firstName);
  late final _last = TextEditingController(text: widget.contact.lastName);

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ref
        .read(contactsProvider.notifier)
        .rename(
          widget.contact.userId,
          firstName: _first.text,
          lastName: _last.text,
        );
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    result.match(
      (failure) => setState(() {
        _busy = false;
        _error = contactFailureMessage(failure, l10n);
      }),
      (_) => Navigator.of(context).pop(true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return _ContactFormDialog(
      title: l10n.contactsRenameTitle,
      submitLabel: l10n.save,
      onSubmit: _submit,
      isBusy: _busy,
      error: _error,
      children: [
        _NameFields(
          first: _first,
          last: _last,
          enabled: !_busy,
          autofocus: true,
          onSubmitted: _submit,
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          l10n.contactsRenameHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ImportContactsDialog extends ConsumerStatefulWidget {
  const _ImportContactsDialog();

  @override
  ConsumerState<_ImportContactsDialog> createState() =>
      _ImportContactsDialogState();
}

class _ImportContactsDialogState extends ConsumerState<_ImportContactsDialog> {
  final _text = TextEditingController();

  ContactImportDraft _draft = const ContactImportDraft();
  bool _busy = false;
  String? _error;

  /// One `Idempotency-Key` per batch, kept for as long as the dialog is
  /// open: pressing Import again after a lost answer resends the same batch
  /// under the same key, and the server answers from its record instead of
  /// importing it twice (api-docs §4.11).
  final Map<String, String> _keys = <String, String>{};

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  String _keyFor(List<ContactImportEntry> batch) {
    final fingerprint = batch
        .map((entry) => entry.email.toLowerCase())
        .join('\n');
    return _keys.putIfAbsent(fingerprint, () => const Uuid().v4());
  }

  Future<void> _submit() async {
    if (_draft.isEmpty) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final Either<Failure, ContactImportResult> result = await ref
        .read(contactsProvider.notifier)
        .import(_draft.entries, keyFor: _keyFor);
    if (!mounted) return;

    final l10n = AppLocalizations.of(context);
    result.match(
      (failure) => setState(() {
        _busy = false;
        _error = contactFailureMessage(failure, l10n);
      }),
      (imported) => Navigator.of(context).pop(imported),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return _ContactFormDialog(
      title: l10n.contactsImportAction,
      submitLabel: l10n.contactsImportSubmit,
      onSubmit: _draft.isEmpty ? null : _submit,
      isBusy: _busy,
      error: _error,
      children: [
        Text(l10n.contactsImportExplain, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.x4),
        TextField(
          controller: _text,
          enabled: !_busy,
          autofocus: true,
          autocorrect: false,
          minLines: 4,
          maxLines: 8,
          keyboardType: TextInputType.multiline,
          onChanged: (value) =>
              setState(() => _draft = ContactImportParser.parse(value)),
          decoration: InputDecoration(
            labelText: l10n.contactsImportFieldLabel,
            hintText: l10n.contactsImportFieldHint,
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(l10n.contactsImportFound(_draft.entries.length), style: muted),
        if (_draft.rejected.isNotEmpty)
          Text(
            l10n.contactsImportSkipped(_draft.rejected.length),
            style: muted,
          ),
      ],
    );
  }
}
