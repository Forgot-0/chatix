import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/storage/cache/attachment_file_cache.dart';

/// The cache limit is a setting, so the cache has to follow it: raising or
/// lowering the budget has to take effect on the next download rather than
/// on the next launch.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> boot() async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('the cache starts at the default budget', () async {
    final container = await boot();

    expect(
      container.read(attachmentFileCacheProvider).maxBytes,
      MediaSettings.defaultCacheLimitBytes,
    );
  });

  test('changing the limit resizes the cache without a restart', () async {
    final container = await boot();
    container.listen(attachmentFileCacheProvider, (_, _) {});

    final raised = MediaSettings.cacheLimitSteps.last;
    await container.read(mediaSettingsProvider.notifier).setCacheLimit(raised);

    expect(container.read(attachmentFileCacheProvider).maxBytes, raised);
  });
}
