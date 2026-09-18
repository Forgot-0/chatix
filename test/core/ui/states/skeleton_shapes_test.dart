import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_feed_skeleton.dart';

void main() {
  Widget host(Widget child) => MaterialApp(
    home: MediaQuery(
      // Reduced motion, so the shimmer holds still and the test is not
      // waiting on a loop that never ends.
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: child),
    ),
  );

  testWidgets('the feed skeleton reads as a conversation, not a list', (
    tester,
  ) async {
    await tester.pumpWidget(host(const ChatFeedSkeleton()));
    await tester.pump();

    expect(tester.takeException(), isNull);

    final bones = find.byType(AppBone);
    expect(bones, findsNWidgets(6));

    final width = tester.getSize(find.byType(ChatFeedSkeleton)).width;
    final lefts = <double>[];
    final widths = <double>[];

    for (var i = 0; i < 6; i++) {
      lefts.add(tester.getTopLeft(bones.at(i)).dx);
      widths.add(tester.getSize(bones.at(i)).width);
    }

    // Both sides are used — a column of identical bars is a list, not a
    // conversation — and nothing runs the full width of the screen.
    expect(lefts.toSet().length, greaterThan(1));
    expect(widths.every((w) => w < width), isTrue);
  });

  testWidgets('an image placeholder fills its tile without a spinner', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const SizedBox(
          width: 120,
          height: 90,
          child: AttachmentImagePlaceholder(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getSize(find.byType(AppBone)), const Size(120, 90));
  });
}
