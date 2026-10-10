import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/features/chat/presentation/providers/chat_local_prefs_provider.dart';

/// How tall the on-screen keyboard was the last time it was fully up, or
/// null before this device has shown one.
///
/// The emoji panel opens at exactly this height. That is the whole trick
/// behind swapping one for the other without the conversation moving: the
/// composer stays where the keyboard put it, and the panel fills the same
/// space the keyboard leaves. Kept across launches, so the first emoji of the
/// day does not open at a guess.
class ComposerKeyboardHeightController extends Notifier<double?> {
  @override
  double? build() =>
      ref.watch(chatLocalPrefsStoreProvider).readKeyboardHeight();

  void remember(double height) {
    if (height < EmojiPanelSizes.minKeyboard) return;

    final rounded = height.roundToDouble();
    if (state == rounded) return;
    state = rounded;

    unawaited(
      ref
          .read(chatLocalPrefsStoreProvider)
          .writeKeyboardHeight(rounded)
          .catchError(
            (Object error) => Logger.warning(
              'Chat prefs: keyboard height not persisted ($error)',
            ),
          ),
    );
  }
}

final composerKeyboardHeightProvider =
    NotifierProvider<ComposerKeyboardHeightController, double?>(
      ComposerKeyboardHeightController.new,
    );
