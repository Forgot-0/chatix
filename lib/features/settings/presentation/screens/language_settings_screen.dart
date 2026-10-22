import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/localization_providers.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/l10n/app_localizations_delegate.dart';
import 'package:chatix/l10n/l10n.dart' as legacy;

/// Settings → Language: every language the app is translated into, each
/// under its own name, the one on screen ticked.
///
/// Names are written the way their speakers write them — "Русский", not
/// "Russian" — because the person looking for their language may not read
/// the one the app is in now.
class LanguageSettingsScreen extends ConsumerWidget {
  const LanguageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.language)),
      body: AppContentWidth(
        child: ListView(
          key: const PageStorageKey<String>('language-list'),
          padding: const EdgeInsets.only(
            top: AppSpacing.x2,
            bottom: AppSpacing.x8,
          ),
          children: [
            AppGroupedSection(
              footer: l10n.languageScreenNote,
              dividerIndent: AppSpacing.x4,
              children: [
                for (final locale in legacy.AppLocalizations.supportedLocales)
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: locale.languageCode == current,
                    child: AppGroupedTile(
                      title: LocalizationUtils.getLocaleName(locale),
                      showChevron: false,
                      trailing: locale.languageCode == current
                          ? Icon(Icons.check_rounded, color: scheme.primary)
                          : null,
                      onTap: () => ref
                          .read(persistentLocaleProvider.notifier)
                          .setLocale(locale),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
