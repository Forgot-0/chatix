import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/utils/slow_mode_presets.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

void main() {
  final ru = lookupAppLocalizations(const Locale('ru'));
  final en = lookupAppLocalizations(const Locale('en'));

  test('Off · 10 s · 30 s · 1 min · 5 min · 15 min · 1 h, in Russian', () {
    expect(
      [for (final s in SlowModePresets.seconds) slowModeLabel(s, ru)],
      ['Выкл', '10 с', '30 с', '1 мин', '5 мин', '15 мин', '1 ч'],
    );
  });

  test('and in English', () {
    expect(
      [for (final s in SlowModePresets.seconds) slowModeLabel(s, en)],
      ['Off', '10 s', '30 s', '1 min', '5 min', '15 min', '1 h'],
    );
  });

  test('every step is inside what the API takes', () {
    for (final seconds in SlowModePresets.seconds) {
      expect(
        seconds,
        inInclusiveRange(0, CreateChatUseCase.maxSlowModeSeconds),
      );
    }
  });

  test('an interval set elsewhere stays on the list, in its place', () {
    expect(SlowModePresets.including(45), [0, 10, 30, 45, 60, 300, 900, 3600]);
    expect(slowModeLabel(45, ru), '45 с');
    expect(slowModeLabel(7200, ru), '2 ч');
    expect(slowModeLabel(120, ru), '2 мин');
  });

  test('a preset is not listed twice', () {
    expect(SlowModePresets.including(300), SlowModePresets.seconds);
    expect(SlowModePresets.including(0), SlowModePresets.seconds);
  });
}
