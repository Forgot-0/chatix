import 'package:flutter/material.dart';
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
          builder: (context) => AlertDialog(
            title: const Text('Enjoying the app?'),
            content: const Text(
              'Would you like to share your feedback with us?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No thanks'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Sure!'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldContinue || !context.mounted) return;

    final hasFeedback = await reviewService.showFeedbackForm(
      context: context,
      title: 'Your Feedback Matters',
      message:
          'Please share your thoughts about the app. If you\'re enjoying it, a review on the app store would be greatly appreciated!',
    );

    if (!hasFeedback) {
      await reviewService.requestReview();
    }
  }
}
