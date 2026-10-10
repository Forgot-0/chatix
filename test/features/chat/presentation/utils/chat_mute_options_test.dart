import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/presentation/utils/chat_mute_options.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

void main() {
  final now = DateTime(2026, 10, 11, 12);

  test('offers an hour, eight hours, two days and for good, in that order', () {
    expect(ChatMuteOption.values, [
      ChatMuteOption.hour,
      ChatMuteOption.eightHours,
      ChatMuteOption.twoDays,
      ChatMuteOption.forever,
    ]);
  });

  test('turns each span into a deadline from the moment it is picked', () {
    expect(ChatMuteOption.hour.untilFrom(now), DateTime(2026, 10, 11, 13));
    expect(
      ChatMuteOption.eightHours.untilFrom(now),
      DateTime(2026, 10, 11, 20),
    );
    expect(ChatMuteOption.twoDays.untilFrom(now), DateTime(2026, 10, 13, 12));
  });

  test('leaves "forever" for the use case to date', () {
    // `UpdateChatStateUseCase.mute` sends its own far-off date for null.
    expect(ChatMuteOption.forever.untilFrom(now), isNull);
  });

  test('is labelled in the reader\'s language', () {
    final en = AppLocalizationsEn();
    final ru = AppLocalizationsRu();

    expect(ChatMuteOption.twoDays.label(en), 'Mute for 2 days');
    expect(ChatMuteOption.twoDays.label(ru), 'Выключить на 2 дня');
    expect(
      ChatMuteOption.values.map((option) => option.label(ru)).toSet(),
      hasLength(ChatMuteOption.values.length),
    );
  });
}
