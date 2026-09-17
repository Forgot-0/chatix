import 'package:flutter/material.dart';

import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/utils/call_layout.dart';
import 'package:chatix/features/chat/presentation/widgets/call_participant_tile.dart';

/// The room, laid out.
///
/// [CallLayoutMode.grid] divides the space evenly using [callGridFor]; up to
/// four people the tiles grow to fill the screen, past that the grid keeps a
/// readable tile size and scrolls. [CallLayoutMode.speaker] gives the focused
/// participant everything and puts the rest in a filmstrip underneath.
class CallParticipantGrid extends StatelessWidget {
  const CallParticipantGrid({
    super.key,
    required this.participants,
    required this.layout,
    required this.profiles,
    this.pinnedIdentity,
    this.onTapParticipant,
    this.muteBuilder,
  });

  final List<CallParticipant> participants;
  final CallLayoutMode layout;

  /// Chat members by user id, so a tile can draw a real avatar and name.
  final Map<int, ChatProfileEntity> profiles;

  final String? pinnedIdentity;

  final void Function(CallParticipant participant)? onTapParticipant;

  /// Returns the moderator mute callback for one participant, or null when
  /// that participant may not be muted by this viewer.
  final void Function(bool muted)? Function(CallParticipant participant)?
  muteBuilder;

  static const double _gap = 8;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth > constraints.maxHeight;

        if (layout == CallLayoutMode.speaker && participants.length > 1) {
          return _speaker(isLandscape: isLandscape);
        }

        final spec = callGridFor(
          count: participants.length,
          isLandscape: isLandscape,
        );

        return spec.isScrollable ? _scrollingGrid(spec) : _fixedGrid(spec);
      },
    );
  }

  Widget _tile(CallParticipant participant, {bool compact = false}) {
    final userId = participant.userId;

    return CallParticipantTile(
      key: ValueKey('${participant.identity}-$compact'),
      participant: participant,
      profile: userId == null ? null : profiles[userId],
      isPinned: participant.identity == pinnedIdentity,
      compact: compact,
      onTap: onTapParticipant == null
          ? null
          : () => onTapParticipant!(participant),
      onMute: muteBuilder?.call(participant),
    );
  }

  /// One to four tiles, sized to fill exactly — no scrolling, no leftovers.
  Widget _fixedGrid(CallGridSpec spec) {
    final rows = spec.rows!;

    return Padding(
      padding: const EdgeInsets.all(_gap / 2),
      child: Column(
        children: [
          for (var row = 0; row < rows; row++)
            Expanded(
              child: Row(
                children: [
                  for (var column = 0; column < spec.columns; column++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(_gap / 2),
                        child: _cellAt(row * spec.columns + column),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cellAt(int index) {
    if (index >= participants.length) return const SizedBox.shrink();
    return _tile(participants[index]);
  }

  Widget _scrollingGrid(CallGridSpec spec) {
    return GridView.builder(
      padding: const EdgeInsets.all(_gap),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: spec.columns,
        crossAxisSpacing: _gap,
        mainAxisSpacing: _gap,
        childAspectRatio: spec.tileAspectRatio,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) => _tile(participants[index]),
    );
  }

  Widget _speaker({required bool isLandscape}) {
    final focused = callFocusedParticipant(
      participants,
      pinnedIdentity: pinnedIdentity,
    );
    final rest = participants
        .where((p) => p.identity != focused?.identity)
        .toList();

    final filmstrip = SizedBox(
      height: isLandscape ? 96 : 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _gap),
        itemCount: rest.length,
        separatorBuilder: (_, _) => const SizedBox(width: _gap),
        itemBuilder: (context, index) => AspectRatio(
          aspectRatio: 3 / 4,
          child: _tile(rest[index], compact: true),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: _gap),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _gap),
              child: focused == null ? const SizedBox.shrink() : _tile(focused),
            ),
          ),
          if (rest.isNotEmpty) ...[const SizedBox(height: _gap), filmstrip],
        ],
      ),
    );
  }
}
