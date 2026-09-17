import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_profile_entity.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/call_participant_grid.dart';
import 'package:chatix/features/chat/presentation/widgets/call_participant_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

CallParticipant person(
  String identity, {
  bool isLocal = false,
  bool microphone = true,
}) => CallParticipant(
  identity: identity,
  userId: int.tryParse(identity),
  name: 'Name $identity',
  isLocal: isLocal,
  isSpeaking: false,
  isMicrophoneEnabled: microphone,
  isCameraEnabled: false,
  videoTrack: null,
);

void main() {
  Future<void> pumpGrid(
    WidgetTester tester, {
    required List<CallParticipant> participants,
    required CallLayoutMode layout,
    Map<int, ChatProfileEntity> profiles = const {},
    String? pinnedIdentity,
    void Function(bool muted)? Function(CallParticipant)? muteBuilder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CallParticipantGrid(
            participants: participants,
            layout: layout,
            profiles: profiles,
            pinnedIdentity: pinnedIdentity,
            muteBuilder: muteBuilder,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty room draws nothing', (tester) async {
    await pumpGrid(tester, participants: const [], layout: CallLayoutMode.grid);

    expect(find.byType(CallParticipantTile), findsNothing);
  });

  testWidgets('the grid draws one tile per participant', (tester) async {
    await pumpGrid(
      tester,
      participants: [person('1', isLocal: true), person('2'), person('3')],
      layout: CallLayoutMode.grid,
    );

    expect(find.byType(CallParticipantTile), findsNWidgets(3));
  });

  testWidgets('past four the grid scrolls instead of shrinking', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      participants: [for (var i = 1; i <= 6; i++) person('$i')],
      layout: CallLayoutMode.grid,
    );

    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('speaker view keeps everyone, one large and the rest compact', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      participants: [person('1', isLocal: true), person('2'), person('3')],
      layout: CallLayoutMode.speaker,
      pinnedIdentity: '2',
    );

    final tiles = tester
        .widgetList<CallParticipantTile>(find.byType(CallParticipantTile))
        .toList();

    expect(tiles.length, 3);
    final large = tiles.where((tile) => !tile.compact).toList();
    expect(large.length, 1);
    expect(large.single.participant.identity, '2');
    expect(large.single.isPinned, isTrue);
  });

  testWidgets('speaker view with one participant falls back to the grid', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      participants: [person('1', isLocal: true)],
      layout: CallLayoutMode.speaker,
    );

    final tile = tester.widget<CallParticipantTile>(
      find.byType(CallParticipantTile),
    );
    expect(tile.compact, isFalse);
  });

  testWidgets('the moderator mute button appears only where allowed', (
    tester,
  ) async {
    await pumpGrid(
      tester,
      participants: [person('1', isLocal: true), person('2')],
      layout: CallLayoutMode.grid,
      muteBuilder: (participant) => participant.identity == '2' ? (_) {} : null,
    );

    final tiles = tester
        .widgetList<CallParticipantTile>(find.byType(CallParticipantTile))
        .toList();

    expect(
      tiles.firstWhere((t) => t.participant.identity == '1').onMute,
      isNull,
    );
    expect(
      tiles.firstWhere((t) => t.participant.identity == '2').onMute,
      isNotNull,
    );
  });

  testWidgets('a tile names the local participant "You"', (tester) async {
    await pumpGrid(
      tester,
      participants: [person('7', isLocal: true), person('8')],
      layout: CallLayoutMode.grid,
    );

    expect(find.text('You'), findsOneWidget);
    expect(find.text('Name 8'), findsOneWidget);
  });
}
