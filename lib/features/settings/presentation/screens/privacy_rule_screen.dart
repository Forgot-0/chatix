import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/cards/app_grouped_section.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/presentation/providers/privacy_settings_provider.dart';
import 'package:chatix/features/settings/presentation/utils/privacy_labels.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One privacy rule: who it lets in — everybody, my contacts, nobody — and
/// the people it makes an exception for either way (api-docs §4.14).
///
/// Only the lists that mean something under the answer are offered: "never
/// allow" when everybody is allowed, "always allow" when nobody is, both
/// for contacts. A change is sent the moment it is made.
class PrivacyRuleScreen extends ConsumerWidget {
  const PrivacyRuleScreen({super.key, required this.rule});

  final PrivacyRule rule;

  Future<void> _set(
    BuildContext context,
    WidgetRef ref,
    PrivacyVisibility visibility,
  ) async {
    final l10n = AppLocalizations.of(context);
    final failure = await ref
        .read(privacySettingsProvider.notifier)
        .setVisibility(rule, visibility);
    if (failure == null || !context.mounted) return;
    AppSnackbar.failure(
      context,
      friendlyFailureMessage(
        failure,
        l10n: l10n,
        fallback: l10n.privacySaveFailed,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(privacySettingsProvider);
    final value = settings.value;

    return Scaffold(
      appBar: AppBar(title: Text(rule.title(l10n))),
      body: value == null
          ? settings.hasError
                ? AppErrorState(
                    error: settings.error,
                    fallbackMessage: l10n.privacyRulesLoadFailed,
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(privacySettingsProvider),
                  )
                : const AppListSkeleton(itemCount: 3)
          : AppContentWidth(
              child: ListView(
                key: PageStorageKey<String>('privacy-rule-${rule.slug}'),
                padding: const EdgeInsets.only(
                  top: AppSpacing.x2,
                  bottom: AppSpacing.x8,
                ),
                children: [
                  AppGroupedSection(
                    header: rule.question(l10n),
                    footer: rule.footer(l10n),
                    dividerIndent: AppSpacing.x4,
                    children: [
                      for (final visibility in PrivacyVisibility.values)
                        Semantics(
                          inMutuallyExclusiveGroup: true,
                          checked: value.visibilityOf(rule) == visibility,
                          child: AppGroupedTile(
                            title: visibility.label(l10n),
                            showChevron: false,
                            trailing: value.visibilityOf(rule) == visibility
                                ? Icon(
                                    Icons.check_rounded,
                                    color: scheme.primary,
                                  )
                                : null,
                            onTap: () => _set(context, ref, visibility),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: SettingsLayout.groupGap),
                  AppGroupedSection(
                    header: l10n.privacyExceptionsSection,
                    footer: l10n.privacyExceptionsFooter,
                    children: [
                      for (final kind in PrivacyExceptionKind.values)
                        if (value.visibilityOf(rule).offers(kind))
                          AppGroupedTile(
                            icon: kind == PrivacyExceptionKind.allow
                                ? Icons.person_add_alt_1_rounded
                                : Icons.person_remove_alt_1_rounded,
                            plateColor: kind == PrivacyExceptionKind.allow
                                ? AppPlatePalette.mint
                                : AppPlatePalette.coral,
                            title: kind.title(l10n),
                            value: _countOf(
                              l10n,
                              value.exceptionsOf(rule).of(kind).length,
                            ),
                            onTap: () => context.push(
                              PrivacyExceptionsRoute.locationOf(
                                rule.slug,
                                kind.slug,
                              ),
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  static String _countOf(AppLocalizations l10n, int count) =>
      count == 0 ? l10n.privacyExceptionsAdd : l10n.privacyPeopleCount(count);
}
