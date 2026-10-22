import 'package:chatix/features/auth/presentation/utils/auth_failure_presentation.dart';

/// Where a server's answer to an auth form is shown: under the field it is
/// about, or in the banner above the form.
///
/// A field error lasts only while the field still holds what was sent — the
/// complaint was about the old value, and leaving "this username is taken"
/// under a username that has since been changed reads as the new one being
/// taken too. Once the reader edits it the message goes, and the next
/// attempt says what it says.
class AuthFormErrors {
  AuthFormErrors(this.fields);

  /// The fields the form has. An error about any other field, or about none,
  /// belongs in the banner.
  final Set<String> fields;

  Map<String, String> _sent = const <String, String>{};

  /// What the attempt about to be made is sending, field by field.
  void remember(Map<String, String> sent) => _sent = Map.unmodifiable(sent);

  /// The message to show under [field], while every one of [field] and
  /// [alsoAbout] still holds what was sent. [current] reads a field's value
  /// now.
  ///
  /// [alsoAbout] is for an error shown on one field but caused by the pair:
  /// "wrong username or password" sits under the password, and is just as
  /// stale once the username has been retyped.
  String? under(
    AuthErrorInfo? error,
    String field,
    String Function(String field) current, {
    Set<String> alsoAbout = const {},
  }) {
    if (error == null || error.field != field) return null;
    for (final name in {field, ...alsoAbout}) {
      if (current(name) != _sent[name]) return null;
    }
    return error.message;
  }

  /// [error], when none of the form's fields can carry it.
  AuthErrorInfo? inBanner(AuthErrorInfo? error) {
    if (error == null) return null;
    return fields.contains(error.field) ? null : error;
  }
}
