import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts taps on the version line in About — seven in a row open the
/// developer menu, the way Android hides its own.
///
/// A burst, not a tally: a pause longer than [resetAfter] starts the count
/// again, so somebody who taps the version now and then over a week does
/// not stumble into it.
class DevMenuTapCounter {
  DevMenuTapCounter({
    this.required = defaultRequired,
    this.resetAfter = defaultResetAfter,
    DateTime Function()? now,
  }) : assert(required > 0, 'zero taps would open it by looking at it'),
       _now = now ?? DateTime.now;

  static const int defaultRequired = 7;
  static const Duration defaultResetAfter = Duration(seconds: 2);

  /// From this many taps left, each tap says how many are still to go.
  /// Fewer would be a secret nobody finds twice; every tap would be noise
  /// for somebody who only meant to read the version.
  static const int hintFrom = 4;

  final int required;
  final Duration resetAfter;
  final DateTime Function() _now;

  int _count = 0;
  DateTime? _last;

  /// Records a tap and answers how many are still needed: zero means this
  /// was the one that opened it.
  int tap() {
    final now = _now();
    final last = _last;
    if (last != null && now.difference(last) > resetAfter) _count = 0;
    _last = now;
    _count = math.min(_count + 1, required);
    return required - _count;
  }

  void reset() {
    _count = 0;
    _last = null;
  }
}

/// Where "the developer menu is open" is kept.
abstract interface class DevMenuStore {
  bool readUnlocked();

  Future<void> writeUnlocked(bool value);
}

/// The default: forgotten on restart. What tests get without asking; the
/// app overrides it with [PrefsDevMenuStore] in `main()`.
class InMemoryDevMenuStore implements DevMenuStore {
  InMemoryDevMenuStore([this._unlocked = false]);

  bool _unlocked;

  @override
  bool readUnlocked() => _unlocked;

  @override
  Future<void> writeUnlocked(bool value) async => _unlocked = value;
}

/// The flag in the preferences file, so a menu opened once stays open —
/// in a release build as much as in a debug one.
class PrefsDevMenuStore implements DevMenuStore {
  const PrefsDevMenuStore(this._prefs);

  final SharedPreferences _prefs;

  static const String storageKey = 'settings.dev_menu_unlocked.v1';

  @override
  bool readUnlocked() => _prefs.getBool(storageKey) ?? false;

  @override
  Future<void> writeUnlocked(bool value) => _prefs.setBool(storageKey, value);
}

final devMenuStoreProvider = Provider<DevMenuStore>(
  (ref) => InMemoryDevMenuStore(),
);

/// Whether the developer menu is open on this device.
class DevMenuController extends Notifier<bool> {
  @override
  bool build() => ref.watch(devMenuStoreProvider).readUnlocked();

  Future<void> unlock() => _set(true);

  /// Puts the menu away again — and stops anything it had switched on, so
  /// hiding it leaves nothing running that the reader can no longer see.
  Future<void> hide() async {
    ref.read(socketRecordingSwitchProvider.notifier).set(false);
    await _set(false);
  }

  Future<void> _set(bool value) async {
    if (value == state) return;
    state = value;
    await ref.read(devMenuStoreProvider).writeUnlocked(value);
  }
}

final devMenuUnlockedProvider = NotifierProvider<DevMenuController, bool>(
  DevMenuController.new,
);

/// The developer menu's "record WebSocket frames", for this run only.
///
/// On top of the remote `enable_ws_protocol_log` flag rather than instead
/// of it: either one turns recording on. Never written down — the buffer
/// holds message text, and a recording somebody forgot about should not
/// survive a restart.
class SocketRecordingSwitch extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final socketRecordingSwitchProvider =
    NotifierProvider<SocketRecordingSwitch, bool>(SocketRecordingSwitch.new);
