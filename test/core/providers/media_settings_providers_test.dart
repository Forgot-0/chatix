import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chatix/core/network/offline_sync_providers.dart';
import 'package:chatix/core/network/connectivity_providers.dart';
import 'package:chatix/core/providers/media_settings_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';

class _MockConnectivity extends Mock implements Connectivity {}

/// Whether a video note may start playing on its own is two facts answered
/// as one: what the reader asked for, and what they are connected through.
/// The platform's own data saver is not readable from Flutter, so "Wi-Fi
/// only" is the app's stand-in for it — and the default, because nobody
/// should spend mobile data without having said so.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockConnectivity connectivity;
  late StreamController<List<ConnectivityResult>> changes;

  setUp(() {
    connectivity = _MockConnectivity();
    changes = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(changes.close);
  });

  Future<ProviderContainer> boot({
    List<ConnectivityResult> on = const [ConnectivityResult.wifi],
    Map<String, Object> stored = const {},
  }) async {
    when(connectivity.checkConnectivity).thenAnswer((_) async => on);
    when(() => connectivity.onConnectivityChanged).thenAnswer(
      (_) => changes.stream,
    );

    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        connectivityProvider.overrideWithValue(connectivity),
      ],
    );
    addTearDown(container.dispose);

    // The first reading is awaited rather than assumed: `checkConnectivity`
    // is a round trip to the platform.
    container.listen(connectivityStatusProvider, (_, _) {});
    await container.read(connectivityStatusProvider.future);
    return container;
  }

  group('the setting', () {
    test('defaults to Wi-Fi only', () async {
      final container = await boot();

      expect(
        container.read(mediaSettingsProvider).videoNoteAutoplay,
        MediaAutoplay.wifiOnly,
      );
    });

    test('survives a restart', () async {
      final container = await boot();
      await container
          .read(mediaSettingsProvider.notifier)
          .setVideoNoteAutoplay(MediaAutoplay.never);

      // A second container stands in for the next launch: same store, new
      // state.
      final prefs = await SharedPreferences.getInstance();
      final relaunched = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(relaunched.dispose);

      expect(
        relaunched.read(mediaSettingsProvider).videoNoteAutoplay,
        MediaAutoplay.never,
      );
    });

    test('a stored value that makes no sense falls back to the default',
        () async {
      final container = await boot(stored: {'media_settings': 'not json'});

      expect(
        container.read(mediaSettingsProvider).videoNoteAutoplay,
        MediaAutoplay.wifiOnly,
      );
    });
  });

  group('whether a note may start itself', () {
    test('"always" does not care what the connection is', () async {
      final container = await boot(on: [ConnectivityResult.mobile]);
      await container
          .read(mediaSettingsProvider.notifier)
          .setVideoNoteAutoplay(MediaAutoplay.always);

      expect(container.read(videoNoteAutoplayProvider), isTrue);
    });

    test('"never" does not either', () async {
      final container = await boot();
      await container
          .read(mediaSettingsProvider.notifier)
          .setVideoNoteAutoplay(MediaAutoplay.never);

      expect(container.read(videoNoteAutoplayProvider), isFalse);
    });

    test('"Wi-Fi only" plays on Wi-Fi and on ethernet', () async {
      final wifi = await boot();
      expect(wifi.read(videoNoteAutoplayProvider), isTrue);

      final wired = await boot(on: [ConnectivityResult.ethernet]);
      expect(wired.read(videoNoteAutoplayProvider), isTrue);
    });

    test('"Wi-Fi only" does not play on mobile data', () async {
      final container = await boot(on: [ConnectivityResult.mobile]);

      expect(container.read(videoNoteAutoplayProvider), isFalse);
    });

    test('walking out of Wi-Fi stops it without a restart', () async {
      final container = await boot();
      container.listen(videoNoteAutoplayProvider, (_, _) {});
      expect(container.read(videoNoteAutoplayProvider), isTrue);

      // The provider yields the first reading before it subscribes to the
      // changes, and a broadcast stream drops what nobody is listening for.
      while (!changes.hasListener) {
        await Future<void>.delayed(Duration.zero);
      }

      changes.add([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(videoNoteAutoplayProvider), isFalse);
    });

    test('an unknown connection counts as one that costs money', () async {
      // Nothing has answered yet: one tap is a smaller imposition than a
      // video the reader is paying for.
      when(connectivity.checkConnectivity).thenAnswer(
        (_) => Completer<List<ConnectivityResult>>().future,
      );
      when(() => connectivity.onConnectivityChanged).thenAnswer(
        (_) => changes.stream,
      );

      SharedPreferences.setMockInitialValues(const {});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          connectivityProvider.overrideWithValue(connectivity),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(videoNoteAutoplayProvider), isFalse);
    });
  });
}
