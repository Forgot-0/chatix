import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/message_meta.dart';
import 'package:chatix/features/chat/presentation/widgets/status_ticks.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

import '../../../../helpers/chat_golden.dart';

/// The time rides the last line of whatever ends a bubble — beside the last
/// word when there is room, on a line of its own at the same edge when there
/// is not — and costs a short message no height at all.
void main() {
  final theme = chatGoldenTheme(dark: false);
  final body = theme.textTheme.bodyMedium!;

  const meta = MessageMeta(label: '09:02', color: Color(0xFF555555));

  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    TextDirection direction = TextDirection.ltr,
    TextScaler scaler = TextScaler.noScaling,
    bool bold = false,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: scaler, boldText: bold),
            child: Directionality(
              textDirection: direction,
              child: Align(alignment: Alignment.topLeft, child: child),
            ),
          ),
        ),
      ),
    ),
  );

  /// How wide [text] is on one line, drawn as the bubble draws it.
  Future<double> widthOf(WidgetTester tester, String text) async {
    await pump(tester, Text(text, style: body));
    return tester.getSize(find.text(text)).width;
  }

  Size metaSize(WidgetTester tester) =>
      tester.getSize(find.byType(MessageMeta));

  Widget layout(Widget content, {double? maxWidth}) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
    child: MessageMetaLayout(content: content, meta: meta),
  );

  Widget anchored(String text) =>
      MessageMetaAnchor(child: Text(text, style: body));

  group('after text', () {
    testWidgets('a short message keeps the time on its only line', (
      tester,
    ) async {
      await pump(tester, layout(anchored('ok'), maxWidth: 300));

      final word = tester.getRect(find.text('ok'));
      final time = tester.getRect(find.byType(MessageMeta));
      final whole = tester.getRect(find.byType(MessageMetaLayout));

      // One line tall: the time cost nothing.
      expect(whole.height, word.height);
      expect(time.bottom, word.bottom);
      // After the word, past the gap, at the far edge.
      expect(time.left, greaterThanOrEqualTo(word.right + ChatLayout.metaGap));
      expect(time.right, whole.right);
    });

    testWidgets('the bubble grows to take the time beside the last word', (
      tester,
    ) async {
      const text = 'On my way';
      final width = await widthOf(tester, text);

      await pump(tester, layout(anchored(text), maxWidth: 400));

      final whole = tester.getRect(find.byType(MessageMetaLayout));
      expect(
        whole.width,
        moreOrLessEquals(width + ChatLayout.metaGap + metaSize(tester).width),
      );
    });

    testWidgets('a last line with no room left sends the time to its own, '
        'at the same edge', (tester) async {
      const text = 'On my way';
      final width = await widthOf(tester, text);

      // Room for the text on one line, not for the time beside it.
      await pump(tester, layout(anchored(text), maxWidth: width + 2));

      final words = tester.getRect(find.text(text));
      final time = tester.getRect(find.byType(MessageMeta));
      final whole = tester.getRect(find.byType(MessageMetaLayout));

      expect(time.top, moreOrLessEquals(words.bottom));
      expect(whole.height, moreOrLessEquals(words.height + time.height));
      expect(time.right, whole.right);
    });

    testWidgets('under a quote wider than the reply, the time is in the '
        'corner, not after the word', (tester) async {
      await pump(
        tester,
        layout(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [const SizedBox(width: 260, height: 40), anchored('ok')],
          ),
          maxWidth: 300,
        ),
      );

      final word = tester.getRect(find.text('ok'));
      final time = tester.getRect(find.byType(MessageMeta));
      final whole = tester.getRect(find.byType(MessageMetaLayout));

      expect(whole.width, 260);
      expect(time.right, whole.right);
      expect(time.bottom, word.bottom);
      expect(whole.height, 40 + word.height);
    });

    testWidgets('right to left, everything mirrors', (tester) async {
      await pump(
        tester,
        layout(anchored('שלום'), maxWidth: 300),
        direction: TextDirection.rtl,
      );

      final word = tester.getRect(find.text('שלום'));
      final time = tester.getRect(find.byType(MessageMeta));
      final whole = tester.getRect(find.byType(MessageMetaLayout));

      expect(time.left, whole.left);
      expect(time.right, lessThanOrEqualTo(word.left - ChatLayout.metaGap));
      expect(time.bottom, word.bottom);
      expect(whole.height, word.height);
    });

    testWidgets('the text is not touched: no placeholder, nothing to find '
        'around', (tester) async {
      await pump(tester, layout(anchored('hello there'), maxWidth: 300));

      expect(find.text('hello there'), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(
        find.text('hello there'),
      );
      expect(paragraph.text.toPlainText(), 'hello there');
    });
  });

  group('over a spacer', () {
    testWidgets('the time sits on the spacer\'s line, at the far edge', (
      tester,
    ) async {
      await pump(
        tester,
        Builder(
          builder: (context) {
            final reserve = MessageMetaReserve.of(context, label: '09:02');
            return layout(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 200, height: 30),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const SizedBox(width: 60, height: 24),
                      reserve.box(),
                    ],
                  ),
                ],
              ),
              maxWidth: 300,
            );
          },
        ),
      );

      final time = tester.getRect(find.byType(MessageMeta));
      final whole = tester.getRect(find.byType(MessageMetaLayout));
      final slot = tester.getRect(find.byType(MessageMetaSpacer));

      expect(time.right, whole.right);
      expect(time.bottom, slot.bottom);
      expect(whole.height, 30 + 24);
    });

    testWidgets('a voice message keeps it where the spacer is', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) {
            final reserve = MessageMetaReserve.of(context, label: '09:02');
            return layout(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 40, height: 20),
                  reserve.box(alignToEnd: false),
                  const SizedBox(width: 80, height: 20),
                ],
              ),
              maxWidth: 400,
            );
          },
        ),
      );

      final time = tester.getRect(find.byType(MessageMeta));
      final slot = tester.getRect(find.byType(MessageMetaSpacer));
      expect(time.right, slot.right);
    });
  });

  testWidgets('with nothing to share a line with, the time takes its own', (
    tester,
  ) async {
    await pump(
      tester,
      layout(const SizedBox(width: 100, height: 100), maxWidth: 300),
    );

    final time = tester.getRect(find.byType(MessageMeta));
    final whole = tester.getRect(find.byType(MessageMetaLayout));
    expect(time.top, whole.top + 100);
    expect(time.right, whole.right);
    expect(whole.height, 100 + time.height);
  });

  group('measured before it is drawn', () {
    final cases = <String, (String, bool, MessageDeliveryStatus?)>{
      'the time': ('09:02', false, null),
      'the time and ticks': ('09:02', false, MessageDeliveryStatus.read),
      'edited': ('21:40', true, null),
      'edited, with ticks': ('9:02 PM', true, MessageDeliveryStatus.sent),
      'a clock tick alone': ('', false, MessageDeliveryStatus.sending),
    };

    for (final scale in [1.0, 1.3, 2.0]) {
      for (final bold in [false, true]) {
        for (final entry in cases.entries) {
          final (label, edited, status) = entry.value;

          testWidgets('${entry.key} at ${scale}x${bold ? ', bold' : ''}', (
            tester,
          ) async {
            late Size measured;
            await pump(
              tester,
              Builder(
                builder: (context) {
                  measured = MessageMeta.measure(
                    context,
                    label: label,
                    isEdited: edited,
                    hasTicks: status != null,
                  );
                  return MessageMeta(
                    label: label,
                    color: const Color(0xFF555555),
                    isEdited: edited,
                    deliveryStatus: status,
                  );
                },
              ),
              scaler: TextScaler.linear(scale),
              bold: bold,
            );

            final drawn = metaSize(tester);
            expect(measured.width, moreOrLessEquals(drawn.width));
            expect(measured.height, moreOrLessEquals(drawn.height));
          });
        }
      }
    }
  });

  testWidgets('tapping the time opens the details', (tester) async {
    var opened = 0;
    await pump(
      tester,
      MessageMetaLayout(
        content: anchored('ok'),
        meta: MessageMeta(
          label: '09:02',
          color: const Color(0xFF555555),
          onTap: () => opened++,
        ),
      ),
    );

    await tester.tap(find.text('09:02'));
    expect(opened, 1);
  });
}
