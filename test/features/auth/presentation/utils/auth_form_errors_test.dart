import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';
import 'package:chatix/features/auth/presentation/utils/auth_form_errors.dart';

/// A server error goes under the field it is about while that field still
/// holds what was sent, and into the banner when the form has no such field.
void main() {
  const taken = AuthErrorInfo(message: 'taken', field: 'username');
  const offline = AuthErrorInfo(message: 'offline');

  late AuthFormErrors errors;
  late Map<String, String> form;

  String current(String field) => form[field] ?? '';

  setUp(() {
    errors = AuthFormErrors(const {'username', 'email', 'password'});
    form = {'username': 'ada', 'email': 'ada@example.com', 'password': 'x'};
    errors.remember(Map.of(form));
  });

  test('a field error sits under its field, and only there', () {
    expect(errors.under(taken, 'username', current), 'taken');
    expect(errors.under(taken, 'email', current), isNull);
    expect(errors.inBanner(taken), isNull);
  });

  test('editing the blamed field retires its error', () {
    form['username'] = 'ada2';

    expect(errors.under(taken, 'username', current), isNull);
    // Retired, not moved: the reader is already fixing it.
    expect(errors.inBanner(taken), isNull);
  });

  test('editing another field leaves it alone', () {
    form['email'] = 'other@example.com';

    expect(errors.under(taken, 'username', current), 'taken');
  });

  test('an error about the pair goes when either half changes', () {
    const wrong = AuthErrorInfo(message: 'wrong', field: 'password');

    expect(
      errors.under(wrong, 'password', current, alsoAbout: {'username'}),
      'wrong',
    );

    form['username'] = 'grace';
    expect(
      errors.under(wrong, 'password', current, alsoAbout: {'username'}),
      isNull,
    );
  });

  test('an error about no field goes in the banner', () {
    expect(errors.inBanner(offline), same(offline));
    expect(errors.under(offline, 'username', current), isNull);
  });

  test('an error about a field the form lacks goes in the banner', () {
    const code = AuthErrorInfo(message: 'bad code', field: 'token');

    expect(errors.inBanner(code), same(code));
  });

  test('no error, nothing anywhere', () {
    expect(errors.inBanner(null), isNull);
    expect(errors.under(null, 'username', current), isNull);
  });
}
