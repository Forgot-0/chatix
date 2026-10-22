import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/settings/dev_menu.dart';

void main() {
  group('DevMenuTapCounter', () {
    late DateTime now;
    late DevMenuTapCounter counter;

    setUp(() {
      now = DateTime(2026, 10, 22, 12);
      counter = DevMenuTapCounter(now: () => now);
    });

    void later(int milliseconds) =>
        now = now.add(Duration(milliseconds: milliseconds));

    test('seven taps in a row open it, counting down on the way', () {
      final left = <int>[];
      for (var i = 0; i < 7; i++) {
        later(300);
        left.add(counter.tap());
      }
      expect(left, [6, 5, 4, 3, 2, 1, 0]);
    });

    test('a pause starts the count again', () {
      for (var i = 0; i < 5; i++) {
        later(300);
        counter.tap();
      }
      later(DevMenuTapCounter.defaultResetAfter.inMilliseconds + 1);

      expect(counter.tap(), 6);
    });

    test('a pause exactly as long as the window still counts', () {
      counter.tap();
      later(DevMenuTapCounter.defaultResetAfter.inMilliseconds);

      expect(counter.tap(), 5);
    });

    test('taps past the last one stay at zero', () {
      for (var i = 0; i < 9; i++) {
        counter.tap();
      }
      expect(counter.tap(), 0);
    });

    test('reset forgets the taps so far', () {
      counter
        ..tap()
        ..tap()
        ..reset();
      expect(counter.tap(), 6);
    });
  });

  group('DevMenuController', () {
    test('starts from what the store remembers', () {
      final container = ProviderContainer(
        overrides: [
          devMenuStoreProvider.overrideWithValue(InMemoryDevMenuStore(true)),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(devMenuUnlockedProvider), isTrue);
    });

    test('unlocking is written down; hiding turns recording off too', () async {
      final store = InMemoryDevMenuStore();
      final container = ProviderContainer(
        overrides: [devMenuStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container.read(devMenuUnlockedProvider.notifier).unlock();
      expect(container.read(devMenuUnlockedProvider), isTrue);
      expect(store.readUnlocked(), isTrue);

      container.read(socketRecordingSwitchProvider.notifier).set(true);
      await container.read(devMenuUnlockedProvider.notifier).hide();

      expect(container.read(devMenuUnlockedProvider), isFalse);
      expect(store.readUnlocked(), isFalse);
      expect(container.read(socketRecordingSwitchProvider), isFalse);
    });
  });

  group('PrefsDevMenuStore', () {
    test('survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(PrefsDevMenuStore(prefs).readUnlocked(), isFalse);
      await PrefsDevMenuStore(prefs).writeUnlocked(true);
      expect(PrefsDevMenuStore(prefs).readUnlocked(), isTrue);
      expect(prefs.getBool(PrefsDevMenuStore.storageKey), isTrue);
    });
  });

  test('the recording switch is never written down', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(socketRecordingSwitchProvider), isFalse);
  });
}
