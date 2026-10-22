import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/settings/data/repositories/privacy_repository_impl.dart';
import 'package:chatix/features/settings/domain/entities/privacy_settings.dart';
import 'package:chatix/features/settings/domain/usecases/update_privacy_settings_use_case.dart';

final updatePrivacySettingsUseCaseProvider =
    Provider<UpdatePrivacySettingsUseCase>(
      (ref) =>
          UpdatePrivacySettingsUseCase(ref.watch(privacyRepositoryProvider)),
    );

/// The signed-in person's privacy settings, as the server has them.
///
/// Every change shows at once and is sent at once: the screen moves the
/// tick, then `PUT /profiles/privacy/` answers with the settings as they now
/// stand and those replace what was guessed. A refused change puts the old
/// value back and hands the failure to the screen to say why.
///
/// Read per account — the id is watched — so a sign-out and a sign-in as
/// somebody else never shows the first person's lists.
class PrivacySettingsController extends AsyncNotifier<PrivacySettings> {
  @override
  Future<PrivacySettings> build() async {
    ref.watch(authProvider.select((user) => user.value?.id));
    final result = await ref.watch(privacyRepositoryProvider).get();
    return result.fold((failure) => throw failure, (settings) => settings);
  }

  Future<Failure?> setVisibility(
    PrivacyRule rule,
    PrivacyVisibility visibility,
  ) {
    final current = state.value;
    if (current == null || current.visibilityOf(rule) == visibility) {
      return Future.value();
    }
    return _apply(
      current,
      current.withVisibility(rule, visibility),
      rules: {rule: visibility},
    );
  }

  Future<Failure?> setExceptions(PrivacyRule rule, PrivacyExceptions lists) {
    final current = state.value;
    if (current == null || current.exceptionsOf(rule) == lists) {
      return Future.value();
    }
    return _apply(
      current,
      current.withExceptions(rule, lists),
      exceptions: {rule: lists},
    );
  }

  Future<Failure?> _apply(
    PrivacySettings before,
    PrivacySettings guess, {
    Map<PrivacyRule, PrivacyVisibility> rules = const {},
    Map<PrivacyRule, PrivacyExceptions> exceptions = const {},
  }) async {
    state = AsyncData(guess);

    final result = await ref
        .read(updatePrivacySettingsUseCaseProvider)
        .execute(rules: rules, exceptions: exceptions);
    if (!ref.mounted) return null;

    return result.fold(
      (failure) {
        // Only undo what this change did: another change may have landed
        // on top of the guess in the meantime.
        final now = state.value ?? guess;
        var undone = now;
        for (final rule in rules.keys) {
          undone = undone.withVisibility(rule, before.visibilityOf(rule));
        }
        for (final rule in exceptions.keys) {
          undone = undone.withExceptions(rule, before.exceptionsOf(rule));
        }
        state = AsyncData(undone);
        return failure;
      },
      (settings) {
        state = AsyncData(settings);
        return null;
      },
    );
  }
}

final privacySettingsProvider =
    AsyncNotifierProvider.autoDispose<
      PrivacySettingsController,
      PrivacySettings
    >(PrivacySettingsController.new);
