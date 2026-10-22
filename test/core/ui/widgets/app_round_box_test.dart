import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/core/ui/widgets/app_round_box.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_list_tile.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_people.dart';
import 'package:chatix/features/chat/presentation/widgets/video_poster_view.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// A circle has to stay a circle whatever box it is handed.
///
/// Nothing in the app gets to pick its own constraints: a `Row` with
/// `CrossAxisAlignment.stretch`, an `Expanded`, a `SizedBox` that names one
/// side, a grid cell with an aspect ratio of its own and a `Stack` with
/// `StackFit.expand` all push a size down. A round thing that simply takes
/// what it is given comes out an oval — which is what [AppRoundBox] is for,
/// and what these check.
void main() {
  /// The two shapes that break a circle: a box far too wide for it, and one
  /// far too tall. Both are tight, so nothing can opt out of them.
  const squeezes = <String, Size>{
    'a box too wide': Size(240, 36),
    'a box too tall': Size(36, 240),
  };

  Future<void> pumpSqueezed(
    WidgetTester tester,
    Widget child, {
    required Size box,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: box.width,
              height: box.height,
              // Stretch rather than Center: the point is to hand the child a
              // tight, lopsided box it cannot refuse.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Expanded(child: child)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// The size of the circle itself — the square [AppRoundBox] settles on,
  /// inside whatever box it was given.
  Size circleIn(WidgetTester tester, Finder of) => tester.getSize(
    find.descendant(of: of, matching: find.byType(AspectRatio)).first,
  );

  group('AppRoundBox', () {
    for (final MapEntry(key: shape, value: box) in squeezes.entries) {
      testWidgets('stays square in $shape', (tester) async {
        await pumpSqueezed(
          tester,
          const AppRoundBox(diameter: 52, child: SizedBox.expand()),
          box: box,
        );

        final size = circleIn(tester, find.byType(AppRoundBox));
        expect(size.width, size.height);
      });
    }

    testWidgets('shrinks to the largest circle that fits', (tester) async {
      await pumpSqueezed(
        tester,
        const AppRoundBox(diameter: 52, child: SizedBox.expand()),
        box: const Size(240, 36),
      );

      expect(circleIn(tester, find.byType(AppRoundBox)).width, 36);
    });

    testWidgets('keeps its own size in a box with room to spare', (
      tester,
    ) async {
      await pumpSqueezed(
        tester,
        const AppRoundBox(diameter: 52, child: SizedBox.expand()),
        box: const Size(240, 120),
      );

      expect(circleIn(tester, find.byType(AppRoundBox)).width, 52);
    });
  });

  /// Every round thing a layout can get at. Each is built the cheapest way
  /// that draws it; what is checked is only its shape.
  final circles = <String, Widget>{
    'an avatar': const ChatAvatar(name: 'Ada', userId: 42),
    'a mention badge': const MentionBadge(),
    'a play badge': const VideoPlayBadge(),
    'a pick check': const PickCheck(selected: true),
    'a transfer ring': const TransferProgressRing(
      state: TransferRingState.running,
      progress: 0.4,
    ),
  };

  for (final MapEntry(key: name, value: circle) in circles.entries) {
    for (final MapEntry(key: shape, value: box) in squeezes.entries) {
      testWidgets('$name stays round in $shape', (tester) async {
        await pumpSqueezed(tester, circle, box: box);

        final size = circleIn(tester, find.byWidget(circle));
        expect(
          size.width,
          size.height,
          reason: '$name came out ${size.width} × ${size.height}',
        );
        // And inside the box it was handed, rather than spilling out of it.
        expect(size.width, lessThanOrEqualTo(box.shortestSide));
      });
    }
  }
}
