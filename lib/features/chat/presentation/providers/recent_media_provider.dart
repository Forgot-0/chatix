import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/chat/data/datasources/recent_media_source.dart';

/// What the strip along the top of the attachment sheet has to draw.
class RecentMediaState extends Equatable {
  const RecentMediaState({
    this.access = RecentMediaAccess.unknown,
    this.items = const [],
    this.isLoading = false,
  });

  final RecentMediaAccess access;
  final List<RecentMediaItem> items;
  final bool isLoading;

  /// Whether the strip belongs on screen at all.
  ///
  /// A platform with no gallery gets no strip and no explanation — there is
  /// nothing the reader could do about it. A refused grant does get a line,
  /// because tapping it can ask again.
  bool get isSupported => access != RecentMediaAccess.unsupported;

  bool get isDenied => access == RecentMediaAccess.denied;

  @override
  List<Object?> get props => [access, items, isLoading];
}

/// The newest few things in the gallery, loaded once the sheet opens.
///
/// Kept out of the sheet's own state so reopening it does not re-ask for the
/// permission and re-read the library — and so a test can hand it a list.
class RecentMediaController extends AsyncNotifier<RecentMediaState> {
  /// Enough to scroll through without turning the sheet into a gallery app.
  static const int limit = 24;

  @override
  Future<RecentMediaState> build() async => const RecentMediaState();

  RecentMediaSource get _source => ref.read(recentMediaSourceProvider);

  /// Asks for access if needed, then loads. Safe to call every time the
  /// sheet opens: a granted library is re-read (new photos show up), a
  /// refused one is not nagged about again unless [force] says so.
  Future<void> load({bool force = false}) async {
    final current = state.value ?? const RecentMediaState();
    if (current.isLoading) return;

    // A refusal is not re-asked on every open — only when the reader taps
    // the line that offers to ask again.
    if (current.isDenied && !force) return;

    state = AsyncValue.data(
      RecentMediaState(
        access: current.access,
        items: current.items,
        isLoading: true,
      ),
    );

    final access = await _source.access();
    if (!ref.mounted) return;

    if (access != RecentMediaAccess.granted) {
      state = AsyncValue.data(RecentMediaState(access: access));
      return;
    }

    final items = await _source.recent(limit: limit);
    if (!ref.mounted) return;

    state = AsyncValue.data(RecentMediaState(access: access, items: items));
  }
}

final recentMediaProvider =
    AsyncNotifierProvider<RecentMediaController, RecentMediaState>(
      RecentMediaController.new,
    );

/// One thumbnail, for as long as something is drawing it.
///
/// A family rather than a map on the state: the strip scrolls, and bytes
/// nobody is looking at any more should be collectable. Both platforms keep
/// their own thumbnail cache underneath, so scrolling back is cheap.
final recentMediaThumbnailProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, id) => ref.read(recentMediaSourceProvider).thumbnail(id),
    );
