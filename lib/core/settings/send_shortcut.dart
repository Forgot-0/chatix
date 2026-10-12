import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Which key sends a message from a physical keyboard.
///
/// A desktop setting only: on a phone the on-screen keyboard's return key
/// always starts a new line and the paper plane sends.
enum SendShortcut {
  /// Enter sends; Shift+Enter starts a new line. The default, as in most
  /// messengers.
  enter,

  /// Ctrl+Enter (Cmd+Enter on a Mac) sends; Enter starts a new line — for
  /// people who write long messages and send them on purpose.
  modifierEnter;

  static SendShortcut fromName(String? name) => SendShortcut.values.firstWhere(
    (value) => value.name == name,
    orElse: () => SendShortcut.enter,
  );
}

/// What a press of Enter in the composer does.
enum ComposerEnterAction {
  /// Send the message (or save the edit).
  send,

  /// Leave the key to the field, which starts a new line.
  newline,
}

/// The rule behind [SendShortcut], apart from any widget so it can be read —
/// and tested — on its own.
abstract final class ComposerEnterRule {
  /// What Enter does with these modifiers held.
  ///
  /// Shift+Enter is a new line in both modes, and Ctrl/Cmd+Enter sends in
  /// both: whichever habit somebody brings from another app, it does what
  /// they expect. Only the bare key depends on the setting.
  static ComposerEnterAction actionFor(
    SendShortcut shortcut, {
    required bool shift,
    required bool primary,
    required bool alt,
  }) {
    if (shift || alt) return ComposerEnterAction.newline;
    if (primary) return ComposerEnterAction.send;
    return shortcut == SendShortcut.enter
        ? ComposerEnterAction.send
        : ComposerEnterAction.newline;
  }
}

/// Where the choice is kept.
abstract interface class SendShortcutStore {
  SendShortcut read();

  Future<void> write(SendShortcut value);
}

/// The default: nothing survives a restart. What tests and widget previews
/// get without asking; the app overrides it with [PrefsSendShortcutStore] in
/// `main()`.
class InMemorySendShortcutStore implements SendShortcutStore {
  InMemorySendShortcutStore([this._value = SendShortcut.enter]);

  SendShortcut _value;

  @override
  SendShortcut read() => _value;

  @override
  Future<void> write(SendShortcut value) async => _value = value;
}

/// The choice in the preferences file: read synchronously, so the first
/// keystroke in the first chat already follows it.
class PrefsSendShortcutStore implements SendShortcutStore {
  const PrefsSendShortcutStore(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'composer.send_shortcut.v1';

  @override
  SendShortcut read() => SendShortcut.fromName(_prefs.getString(storageKey));

  @override
  Future<void> write(SendShortcut value) =>
      _prefs.setString(storageKey, value.name);
}

final sendShortcutStoreProvider = Provider<SendShortcutStore>(
  (ref) => InMemorySendShortcutStore(),
);

class SendShortcutController extends Notifier<SendShortcut> {
  @override
  SendShortcut build() => ref.watch(sendShortcutStoreProvider).read();

  Future<void> set(SendShortcut value) async {
    if (value == state) return;
    state = value;
    await ref.read(sendShortcutStoreProvider).write(value);
  }
}

final sendShortcutProvider =
    NotifierProvider<SendShortcutController, SendShortcut>(
      SendShortcutController.new,
    );
