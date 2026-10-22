import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One line of the release notes: a glyph on its square, what changed, and
/// what that means for the reader.
typedef WhatsNewNote = ({
  IconData icon,
  Color plate,
  String title,
  String body,
});

/// What this release brought, most noticeable first.
///
/// Written for people, not for a changelog: each note says what one can do
/// now, in the reader's language, and there are few enough of them to read
/// in the time it takes to open the sheet.
List<WhatsNewNote> whatsNewNotes(AppLocalizations l10n) => [
  (
    icon: Icons.tune_rounded,
    plate: AppPlatePalette.violet,
    title: l10n.whatsNewSettingsTitle,
    body: l10n.whatsNewSettingsBody,
  ),
  (
    icon: Icons.folder_rounded,
    plate: AppPlatePalette.moss,
    title: l10n.whatsNewFoldersTitle,
    body: l10n.whatsNewFoldersBody,
  ),
  (
    icon: Icons.groups_rounded,
    plate: AppPlatePalette.azure,
    title: l10n.whatsNewChatsTitle,
    body: l10n.whatsNewChatsBody,
  ),
  (
    icon: Icons.desktop_windows_rounded,
    plate: AppPlatePalette.amber,
    title: l10n.whatsNewDesktopTitle,
    body: l10n.whatsNewDesktopBody,
  ),
];

/// Opens the release notes for [version] — or for "this version" while the
/// platform has not said which one that is.
Future<void> showWhatsNewSheet(BuildContext context, {String? version}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => _WhatsNewSheet(version: version),
  );
}

class _WhatsNewSheet extends StatelessWidget {
  const _WhatsNewSheet({required this.version});

  final String? version;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final version = this.version;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x6,
          0,
          AppSpacing.x6,
          AppSpacing.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              version == null
                  ? l10n.aboutWhatsNew
                  : l10n.aboutWhatsNewTitle(version),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.x5),
            for (final note in whatsNewNotes(l10n)) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppIconPlate(icon: note.icon, color: note.plate),
                  const SizedBox(width: SettingsLayout.plateGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SettingsLayout.lineGap),
                        Text(
                          note.body,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x5),
            ],
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        ),
      ),
    );
  }
}
