import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/network/offline_sync_providers.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:chatix/core/settings/media_settings.dart';
import 'package:chatix/core/settings/media_settings_service.dart';

final mediaSettingsServiceProvider = Provider<MediaSettingsService>((ref) {
  return MediaSettingsService(ref.watch(sharedPreferencesProvider));
});

/// What the reader has said about media that plays itself, and the only
/// place that says it.
class MediaSettingsController extends Notifier<MediaSettings> {
  @override
  MediaSettings build() => ref.watch(mediaSettingsServiceProvider).load();

  Future<void> setVideoNoteAutoplay(MediaAutoplay value) =>
      _apply(state.copyWith(videoNoteAutoplay: value));

  Future<void> _apply(MediaSettings next) async {
    if (next == state) return;
    state = next;
    await ref.read(mediaSettingsServiceProvider).save(next);
  }
}

final mediaSettingsProvider =
    NotifierProvider<MediaSettingsController, MediaSettings>(
      MediaSettingsController.new,
    );

/// What this device is connected through, now and whenever it changes.
///
/// The first reading is taken rather than waited for: `onConnectivityChanged`
/// only fires on a *change*, so a stream of it alone says nothing at all
/// until the reader walks into a lift.
final connectivityStatusProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) async* {
  final connectivity = ref.watch(connectivityProvider);

  yield await connectivity.checkConnectivity();
  yield* connectivity.onConnectivityChanged;
});

/// Whether the current connection is one that is not charged by the
/// megabyte.
///
/// Unknown counts as metered. Between starting a video the reader is paying
/// for and making them tap once, the tap is the smaller imposition — and the
/// unknown only lasts until the first reading arrives.
final isOnUnmeteredNetworkProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).value;
  if (status == null) return false;

  return status.any(
    (result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet,
  );
});

/// Whether a video note may start playing on its own right now.
///
/// The setting and the connection, answered as one thing, because every
/// caller wants the answer and none of them want the two halves. A call
/// going on overrules both: a feed that starts talking over a call is a bug
/// wherever the setting stands.
final videoNoteAutoplayProvider = Provider<bool>((ref) {
  final setting = ref.watch(
    mediaSettingsProvider.select((s) => s.videoNoteAutoplay),
  );

  return switch (setting) {
    MediaAutoplay.never => false,
    MediaAutoplay.always => true,
    MediaAutoplay.wifiOnly => ref.watch(isOnUnmeteredNetworkProvider),
  };
});
