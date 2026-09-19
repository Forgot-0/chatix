import 'package:flutter/material.dart';

import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/utils/app_review_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final inAppReviewProvider = Provider<InAppReview>((ref) {
  return InAppReview.instance;
});

final appReviewServiceProvider = Provider<AppReviewService>((ref) {
  final inAppReview = ref.watch(inAppReviewProvider);
  final preferences = ref.watch(sharedPreferencesProvider);

  final service = AppReviewServiceImpl(
    inAppReview: inAppReview,
    preferences: preferences,
    minSessionsBeforeReview: AppConstants.minSessionsBeforeReview,
    minDaysBeforeReview: AppConstants.minDaysBeforeReview,
    minActionsBeforeReview: AppConstants.minActionsBeforeReview,
  );

  service.init();

  return service;
});

final shouldRequestReviewProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final reviewService = ref.watch(appReviewServiceProvider);
  return await reviewService.shouldRequestReview();
});

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferencesProvider not initialized');
});

class SmartReviewPrompt extends ConsumerWidget {
  final Widget child;

  const SmartReviewPrompt({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<bool>>(shouldRequestReviewProvider, (_, state) {
      state.whenData((shouldRequest) {
        if (shouldRequest && context.mounted) {
          _showReviewFlow(context, ref);
        }
      });
    });

    return child;
  }

  Future<void> _showReviewFlow(BuildContext context, WidgetRef ref) async {
    final reviewService = ref.read(appReviewServiceProvider);

    final shouldContinue =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            final l10n = AppLocalizations.of(context);

            return AlertDialog(
              title: Text(l10n.reviewPromptTitle),
              content: Text(l10n.reviewPromptBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.reviewPromptDecline),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.reviewPromptAccept),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldContinue || !context.mounted) return;

    final l10n = AppLocalizations.of(context);
    final hasFeedback = await reviewService.showFeedbackForm(
      context: context,
      title: l10n.feedbackTitle,
      message: l10n.feedbackBody,
    );

    if (!hasFeedback) {
      await reviewService.requestReview();
    }
  }
}
