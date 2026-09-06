import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class AppReviewService {
  Future<bool> shouldRequestReview();

  Future<void> requestReview();

  Future<void> recordAppSession();

  Future<void> recordSignificantAction();

  Future<bool> showFeedbackForm({
    required BuildContext context,
    required String title,
    required String message,
  });

  Future<void> init();
}

class AppReviewServiceImpl implements AppReviewService {
  final InAppReview _inAppReview;
  final SharedPreferences _preferences;

  static const String _keyFirstLaunchTime = 'app_review_first_launch_time';
  static const String _keySessionCount = 'app_review_session_count';
  static const String _keyActionCount = 'app_review_action_count';
  static const String _keyLastReviewRequestTime =
      'app_review_last_request_time';
  static const String _keyHasGivenReview = 'app_review_has_given';

  final int _minSessionsBeforeReview;
  final int _minDaysBeforeReview;
  final int _minActionsBeforeReview;
  final int _daysBetweenReviewRequests;

  AppReviewServiceImpl({
    required InAppReview inAppReview,
    required SharedPreferences preferences,
    int minSessionsBeforeReview = 5,
    int minDaysBeforeReview = 7,
    int minActionsBeforeReview = 10,
    int daysBetweenReviewRequests = 60,
  }) : _inAppReview = inAppReview,
       _preferences = preferences,
       _minSessionsBeforeReview = minSessionsBeforeReview,
       _minDaysBeforeReview = minDaysBeforeReview,
       _minActionsBeforeReview = minActionsBeforeReview,
       _daysBetweenReviewRequests = daysBetweenReviewRequests;

  @override
  Future<void> init() async {
    if (!_preferences.containsKey(_keyFirstLaunchTime)) {
      await _preferences.setInt(
        _keyFirstLaunchTime,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    await recordAppSession();

    debugPrint('⭐️ App review service initialized');
  }

  @override
  Future<bool> shouldRequestReview() async {
    if (_preferences.getBool(_keyHasGivenReview) ?? false) {
      return false;
    }

    final sessionCount = _preferences.getInt(_keySessionCount) ?? 0;
    final actionCount = _preferences.getInt(_keyActionCount) ?? 0;
    final firstLaunchTime =
        _preferences.getInt(_keyFirstLaunchTime) ??
        DateTime.now().millisecondsSinceEpoch;
    final lastReviewRequestTime =
        _preferences.getInt(_keyLastReviewRequestTime) ?? 0;

    final daysSinceFirstLaunch = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(firstLaunchTime))
        .inDays;

    final daysSinceLastReviewRequest = DateTime.now()
        .difference(DateTime.fromMillisecondsSinceEpoch(lastReviewRequestTime))
        .inDays;

    if (lastReviewRequestTime > 0 &&
        daysSinceLastReviewRequest < _daysBetweenReviewRequests) {
      return false;
    }

    return sessionCount >= _minSessionsBeforeReview &&
        daysSinceFirstLaunch >= _minDaysBeforeReview &&
        actionCount >= _minActionsBeforeReview;
  }

  @override
  Future<void> requestReview() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();

        await _preferences.setInt(
          _keyLastReviewRequestTime,
          DateTime.now().millisecondsSinceEpoch,
        );
      } else {
        await _inAppReview.openStoreListing();

        await _preferences.setBool(_keyHasGivenReview, true);
      }
    } catch (e) {
      debugPrint('⭐️ Error requesting review: $e');
    }
  }

  @override
  Future<void> recordAppSession() async {
    final currentCount = _preferences.getInt(_keySessionCount) ?? 0;
    await _preferences.setInt(_keySessionCount, currentCount + 1);
  }

  @override
  Future<void> recordSignificantAction() async {
    final currentCount = _preferences.getInt(_keyActionCount) ?? 0;
    await _preferences.setInt(_keyActionCount, currentCount + 1);

    if (await shouldRequestReview()) {
      await requestReview();
    }
  }

  @override
  Future<bool> showFeedbackForm({
    required BuildContext context,
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();
    bool result = false;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your feedback here',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              result = true;
              debugPrint('⭐️ User feedback: ${controller.text}');
              Navigator.of(context).pop();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    return result;
  }
}
