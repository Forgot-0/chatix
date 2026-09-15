import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/network/offline_sync_providers.dart';

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

/// Whether this device has a link of any kind.
///
/// The question a reconnecting socket is really asking: is there no network,
/// or is there a network and the server is simply not answering? The two
/// deserve different words on screen, and only one of them is something the
/// reader can do anything about.
///
/// Unknown counts as connected. The platform may not answer at all — a
/// desktop build, a test harness — and "waiting for network" shown to
/// somebody whose network is fine is worse than saying nothing.
final hasNetworkLinkProvider = Provider<bool>((ref) {
  final status = ref.watch(connectivityStatusProvider).value;
  if (status == null || status.isEmpty) return true;

  return status.any((result) => result != ConnectivityResult.none);
});
