import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/auth/presentation/utils/auth_field_validators.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

/// The auth form rules speak the reader's language. They used to carry
/// English literals, so a Russian sign-up form said "Username is required".
void main() {
  final AppLocalizations ru = AppLocalizationsRu();
  final AppLocalizations en = AppLocalizationsEn();

  group('in Russian', () {
    test('every rule fails with a Russian sentence', () {
      expect(
        AuthFieldValidators.loginIdentifier(ru)(''),
        ru.validationLoginIdentifierRequired,
      );
      expect(AuthFieldValidators.required(ru)(''), 'Обязательное поле');
      expect(AuthFieldValidators.username(ru)(''), 'Введите имя пользователя');
      expect(AuthFieldValidators.username(ru)('abc'), 'Минимум 4 символа');
      expect(
        AuthFieldValidators.username(ru)('a' * 101),
        'Не больше 100 символов',
      );
      expect(
        AuthFieldValidators.username(ru)('Анна'),
        ru.validationUsernameCharacters,
      );
      expect(AuthFieldValidators.email(ru)(''), 'Введите email');
      expect(AuthFieldValidators.email(ru)('nope'), 'Введите корректный email');
      expect(AuthFieldValidators.password(ru)(''), 'Введите пароль');
      expect(AuthFieldValidators.password(ru)('Ab1!'), 'Минимум 8 символов');
      expect(
        AuthFieldValidators.password(ru)('abcdefg1!'),
        'Добавьте хотя бы одну заглавную букву',
      );
      expect(
        AuthFieldValidators.password(ru)('ABCDEFG1!'),
        'Добавьте хотя бы одну строчную букву',
      );
      expect(
        AuthFieldValidators.password(ru)('Abcdefgh!'),
        'Добавьте хотя бы одну цифру',
      );
      expect(
        AuthFieldValidators.password(ru)('Abcdefg12'),
        'Добавьте хотя бы один спецсимвол: !@#\$%^&*(),.?":{}|<>',
      );
    });

    test('the repeat field compares with the password as it is now', () {
      var password = 'Secret1!';
      final repeat = AuthFieldValidators.passwordRepeat(ru, () => password);

      expect(repeat(''), 'Повторите пароль');
      expect(repeat('Secret1!'), isNull);

      password = 'Changed1!';
      expect(repeat('Secret1!'), 'Пароли не совпадают');
    });
  });

  test('a valid form passes every rule', () {
    expect(AuthFieldValidators.loginIdentifier(en)('ada'), isNull);
    expect(AuthFieldValidators.username(en)("Ada O'Neil-Byron"), isNull);
    expect(AuthFieldValidators.email(en)('ada@example.com'), isNull);
    expect(AuthFieldValidators.password(en)('Secret1!'), isNull);
    expect(AuthFieldValidators.required(en)('x'), isNull);
  });

  test('English keeps the wording it always had', () {
    expect(AuthFieldValidators.username(en)(''), 'Username is required');
    expect(AuthFieldValidators.username(en)('abc'), 'At least 4 characters');
    expect(AuthFieldValidators.password(en)('Ab1!'), 'At least 8 characters');
    expect(
      AuthFieldValidators.passwordRepeat(en, () => 'a')('b'),
      'Passwords do not match',
    );
  });
}
