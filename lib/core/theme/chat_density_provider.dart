import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';

const String _densityKey = 'chat_density';

class ChatDensityController extends Notifier<ChatDensity> {
  @override
  ChatDensity build() {
    final stored = ref.watch(sharedPreferencesProvider).getString(_densityKey);
    return ChatDensity.fromName(stored);
  }

  Future<void> set(ChatDensity density) async {
    if (state == density) return;
    state = density;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_densityKey, density.name);
  }
}

final chatDensityProvider =
    NotifierProvider<ChatDensityController, ChatDensity>(
      ChatDensityController.new,
    );
