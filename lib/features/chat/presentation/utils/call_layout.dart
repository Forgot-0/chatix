import 'package:chatix/features/chat/presentation/providers/call_provider.dart';

/// How many columns and rows a grid of [count] tiles gets, and whether it has
/// to scroll.
///
/// `rows == null` means "as many as it takes": past four participants the
/// tiles stop growing and the grid starts scrolling instead, because a tile
/// smaller than about a third of the screen shows nothing useful.
class CallGridSpec {
  const CallGridSpec({
    required this.columns,
    required this.rows,
    required this.tileAspectRatio,
  });

  final int columns;

  /// null when the grid scrolls.
  final int? rows;

  /// Only consulted when the grid scrolls — a bounded grid divides the space
  /// it is given instead.
  final double tileAspectRatio;

  bool get isScrollable => rows == null;

  @override
  bool operator ==(Object other) =>
      other is CallGridSpec &&
      other.columns == columns &&
      other.rows == rows &&
      other.tileAspectRatio == tileAspectRatio;

  @override
  int get hashCode => Object.hash(columns, rows, tileAspectRatio);

  @override
  String toString() =>
      'CallGridSpec(columns: $columns, rows: $rows, '
      'tileAspectRatio: $tileAspectRatio)';
}

/// The four cases the design calls for: one, two, three-or-four, and the rest.
///
/// One fills the screen. Two split it along the long axis, so each half stays
/// as close to square as the window allows. Three and four take a 2×2 — three
/// leaves one cell empty rather than stretching a tile to double width, which
/// keeps every face the same size. Five and up scroll in a fixed-size grid.
CallGridSpec callGridFor({required int count, required bool isLandscape}) {
  if (count <= 1) {
    return const CallGridSpec(columns: 1, rows: 1, tileAspectRatio: 3 / 4);
  }
  if (count == 2) {
    return isLandscape
        ? const CallGridSpec(columns: 2, rows: 1, tileAspectRatio: 3 / 4)
        : const CallGridSpec(columns: 1, rows: 2, tileAspectRatio: 4 / 3);
  }
  if (count <= 4) {
    return const CallGridSpec(columns: 2, rows: 2, tileAspectRatio: 3 / 4);
  }
  return isLandscape
      ? const CallGridSpec(columns: 3, rows: null, tileAspectRatio: 4 / 3)
      : const CallGridSpec(columns: 2, rows: null, tileAspectRatio: 3 / 4);
}

/// Whether the local camera preview floats as a draggable picture-in-picture
/// instead of taking a cell in the grid.
///
/// It floats only when it is showing video *and* there is somebody else to
/// look at. Alone in the room, or with the camera off, the local tile belongs
/// in the grid like everyone else's.
bool shouldFloatSelfPreview({
  required bool isCameraEnabled,
  required int participantCount,
}) => isCameraEnabled && participantCount > 1;

/// The participants the grid draws, given that the local preview may have
/// floated out of it.
List<CallParticipant> callGridParticipants(
  List<CallParticipant> participants, {
  required bool selfPreviewFloats,
}) {
  if (!selfPreviewFloats) return participants;
  final remote = participants.where((p) => !p.isLocal).toList();
  return remote.isEmpty ? participants : remote;
}

/// Who the speaker layout puts in the big tile.
///
/// The pinned participant when the user has picked one, otherwise whoever is
/// speaking, otherwise the first remote participant — never the local one if
/// there is anybody else, because watching yourself full screen is not what
/// the layout is for.
CallParticipant? callFocusedParticipant(
  List<CallParticipant> participants, {
  String? pinnedIdentity,
}) {
  if (participants.isEmpty) return null;

  if (pinnedIdentity != null) {
    for (final participant in participants) {
      if (participant.identity == pinnedIdentity) return participant;
    }
  }

  CallParticipant? loudest;
  for (final participant in participants) {
    if (!participant.isSpeaking) continue;
    if (loudest == null || participant.audioLevel > loudest.audioLevel) {
      loudest = participant;
    }
  }
  if (loudest != null) return loudest;

  for (final participant in participants) {
    if (!participant.isLocal) return participant;
  }
  return participants.first;
}
