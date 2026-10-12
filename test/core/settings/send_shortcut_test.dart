import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/settings/send_shortcut.dart';

void main() {
  group('ComposerEnterRule', () {
    ComposerEnterAction enter(
      SendShortcut shortcut, {
      bool shift = false,
      bool primary = false,
      bool alt = false,
    }) => ComposerEnterRule.actionFor(
      shortcut,
      shift: shift,
      primary: primary,
      alt: alt,
    );

    test('by default the bare key sends', () {
      expect(enter(SendShortcut.enter), ComposerEnterAction.send);
    });

    test('with Ctrl+Enter chosen the bare key is a new line', () {
      expect(enter(SendShortcut.modifierEnter), ComposerEnterAction.newline);
    });

    test('Ctrl/Cmd+Enter sends whichever is chosen', () {
      for (final shortcut in SendShortcut.values) {
        expect(
          enter(shortcut, primary: true),
          ComposerEnterAction.send,
          reason: '$shortcut',
        );
      }
    });

    test('Shift+Enter and Alt+Enter are a new line whichever is chosen', () {
      for (final shortcut in SendShortcut.values) {
        expect(enter(shortcut, shift: true), ComposerEnterAction.newline);
        expect(enter(shortcut, alt: true), ComposerEnterAction.newline);
        // Shift wins over the modifier: nobody sends by accident while
        // reaching for a capital letter.
        expect(
          enter(shortcut, shift: true, primary: true),
          ComposerEnterAction.newline,
        );
      }
    });
  });

  group('SendShortcut.fromName', () {
    test('reads back every value it wrote', () {
      for (final value in SendShortcut.values) {
        expect(SendShortcut.fromName(value.name), value);
      }
    });

    test('anything unknown is the default', () {
      expect(SendShortcut.fromName(null), SendShortcut.enter);
      expect(SendShortcut.fromName('shiftEnter'), SendShortcut.enter);
    });
  });

  group('the setting', () {
    test('survives a restart in the preferences file', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final first = ProviderContainer(
        overrides: [
          sendShortcutStoreProvider.overrideWithValue(
            PrefsSendShortcutStore(prefs),
          ),
        ],
      );
      addTearDown(first.dispose);
      expect(first.read(sendShortcutProvider), SendShortcut.enter);

      await first
          .read(sendShortcutProvider.notifier)
          .set(SendShortcut.modifierEnter);
      expect(first.read(sendShortcutProvider), SendShortcut.modifierEnter);
      expect(
        prefs.getString(PrefsSendShortcutStore.storageKey),
        'modifierEnter',
      );

      final second = ProviderContainer(
        overrides: [
          sendShortcutStoreProvider.overrideWithValue(
            PrefsSendShortcutStore(prefs),
          ),
        ],
      );
      addTearDown(second.dispose);
      expect(second.read(sendShortcutProvider), SendShortcut.modifierEnter);
    });

    test('without the app wiring it lives in memory', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(sendShortcutProvider.notifier)
          .set(SendShortcut.modifierEnter);
      expect(container.read(sendShortcutProvider), SendShortcut.modifierEnter);
    });
  });
}
