import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/updates/update_service.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return BasicUpdateService(
    androidPackageName: AppConstants.packageName,
    iOSAppId: AppConstants.iOSAppId,
  );
});

final updateCheckProvider = FutureProvider.autoDispose<UpdateCheckResult>((
  ref,
) async {
  final updateService = ref.watch(updateServiceProvider);
  await updateService.init();
  return await updateService.checkForUpdates();
});

final updateInfoProvider = FutureProvider.autoDispose<UpdateInfo?>((ref) async {
  final updateService = ref.watch(updateServiceProvider);
  return await updateService.getUpdateInfo();
});

class UpdateController extends AsyncNotifier<UpdateCheckResult> {
  @override
  Future<UpdateCheckResult> build() async {
    final updateService = ref.watch(updateServiceProvider);
    await updateService.init();
    return await updateService.checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    state = const AsyncValue.loading();

    try {
      final updateService = ref.read(updateServiceProvider);
      final result = await updateService.checkForUpdates();
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<bool> promptForUpdate({bool force = false}) async {
    final updateService = ref.read(updateServiceProvider);
    return await updateService.promptUpdate(force: force);
  }

  Future<bool> openUpdateUrl() async {
    final updateService = ref.read(updateServiceProvider);
    return await updateService.openUpdateUrl();
  }

  Future<UpdateInfo?> getUpdateInfo() async {
    final updateService = ref.read(updateServiceProvider);
    return await updateService.getUpdateInfo();
  }
}

final updateControllerProvider =
    AsyncNotifierProvider<UpdateController, UpdateCheckResult>(
      UpdateController.new,
    );

class UpdateChecker extends ConsumerWidget {
  final Widget child;

  final bool autoPrompt;

  final bool enforceCriticalUpdates;

  const UpdateChecker({
    super.key,
    required this.child,
    this.autoPrompt = true,
    this.enforceCriticalUpdates = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<UpdateCheckResult>>(updateControllerProvider, (
      _,
      state,
    ) {
      state.whenData((result) {
        if (autoPrompt &&
            (result == UpdateCheckResult.updateAvailable ||
                result == UpdateCheckResult.criticalUpdateRequired)) {
          _showUpdateDialog(context, ref, result);
        }
      });
    });

    return child;
  }

  void _showUpdateDialog(
    BuildContext context,
    WidgetRef ref,
    UpdateCheckResult result,
  ) async {
    final updateController = ref.read(updateControllerProvider.notifier);
    final updateInfo = await updateController.getUpdateInfo();

    if (updateInfo == null || !context.mounted) return;

    final isCritical = result == UpdateCheckResult.criticalUpdateRequired;

    showDialog(
      context: context,
      barrierDismissible: !isCritical,
      builder: (context) =>
          UpdateDialog(updateInfo: updateInfo, isCritical: isCritical),
    );
  }
}

class UpdateDialog extends ConsumerWidget {
  final UpdateInfo updateInfo;

  final bool isCritical;

  const UpdateDialog({
    super.key,
    required this.updateInfo,
    this.isCritical = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isCritical,
      child: AlertDialog(
        title: Text(isCritical ? 'Required Update' : 'Update Available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCritical
                    ? 'A critical update (version ${updateInfo.latestVersion}) is required to continue using this app.'
                    : 'A new version (${updateInfo.latestVersion}) is available.',
                style: theme.textTheme.bodyLarge,
              ),
              if (updateInfo.releaseNotes != null) ...[
                const SizedBox(height: 16),
                Text('What\'s new:', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(updateInfo.releaseNotes!),
              ],
            ],
          ),
        ),
        actions: [
          if (!isCritical)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.read(updateControllerProvider.notifier).openUpdateUrl();
            },
            child: Text(isCritical ? 'Update Now' : 'Update'),
          ),
        ],
      ),
    );
  }
}
