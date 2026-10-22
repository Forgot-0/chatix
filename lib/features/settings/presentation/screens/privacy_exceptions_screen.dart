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
import 'package:chatix/features/settings/presentation/widgets/privacy_people.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One of a rule's two lists: the people it always lets in, or never.
///
/// The way in to the picker on top, the people under it, each with a
/// button that takes them off at once. The server keeps only ids
/// (api-docs §4.14), so names come from the address book, or from the
/// person's profile when they are not in it.
class PrivacyExceptionsScreen extends ConsumerWidget {
  const PrivacyExceptionsScreen({
    super.key,
    required this.rule,
    required this.kind,
  });

  final PrivacyRule rule;
  final PrivacyExceptionKind kind;

  Future<void> _remove(BuildContext context, WidgetRef ref, int userId) async {
    final l10n = AppLocalizations.of(context);
    final current = ref.read(privacySettingsProvider).value;
    if (current == null) return;

    final failure = await ref
        .read(privacySettingsProvider.notifier)
        .setExceptions(rule, current.exceptionsOf(rule).without(kind, userId));
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
    final settings = ref.watch(privacySettingsProvider);
    final value = settings.value;
    final people = value?.exceptionsOf(rule).of(kind) ?? const <int>[];

    return Scaffold(
      appBar: AppBar(title: Text(kind.title(l10n))),
      body: value == null
          ? settings.hasError
                ? AppErrorState(
                    error: settings.error,
                    fallbackMessage: l10n.privacyRulesLoadFailed,
                    retryLabel: l10n.retry,
                    onRetry: () => ref.invalidate(privacySettingsProvider),
                  )
                : const AppListSkeleton()
          : AppContentWidth(
              child: ListView(
                key: PageStorageKey<String>(
                  'privacy-exceptions-${rule.slug}-${kind.slug}',
                ),
                padding: const EdgeInsets.only(
                  top: AppSpacing.x2,
                  bottom: AppSpacing.x8,
                ),
                children: [
                  AppGroupedSection(
                    header: rule.title(l10n),
                    footer: l10n.privacyExceptionsLimitHint(
                      PrivacyExceptions.limit,
                    ),
                    dividerIndent: AppSpacing.x4,
                    children: [
                      AppGroupedTile(
                        icon: Icons.person_add_alt_1_rounded,
                        plateColor: AppPlatePalette.violet,
                        title: l10n.privacyExceptionsEdit,
                        onTap: () => context.push(
                          PrivacyExceptionsEditRoute.locationOf(
                            rule.slug,
                            kind.slug,
                          ),
                        ),
                      ),
                      for (final userId in people)
                        PrivacyPersonRow(
                          key: ValueKey<int>(userId),
                          userId: userId,
                          onRemove: () => _remove(context, ref, userId),
                        ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
