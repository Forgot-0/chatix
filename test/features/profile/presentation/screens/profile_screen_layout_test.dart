import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';

import '../../../../helpers/pane_frame.dart';
import '../../../../helpers/profile_screen_harness.dart';

/// Where a profile puts things, in every window it can be opened in, and
/// what the four kinds of profile look like.
///
/// The header used to centre the avatar on the window while the name was
/// centred on the pane, so beside a rail and a chat list the face sat a
/// list's width to the right of the name it belongs to.
void main() {
  setUpAll(ProfileScreenHarness.setUpAll);

  late ProfileScreenHarness harness;
  setUp(() => harness = ProfileScreenHarness());

  Finder avatar() =>
      find.descendant(of: find.byType(Hero), matching: find.byType(ChatAvatar));

  group('the face sits over the name', () {
    for (final window in PaneWindow.values) {
      testWidgets('in a ${window.paneWidth.round()} px pane (${window.name})', (
        tester,
      ) async {
        await harness.pump(tester, profile: kAda, window: window);

        final face = tester.getCenter(avatar());
        final name = tester.getCenter(find.text('Ada Lovelace'));

        expect(face.dx, moreOrLessEquals(name.dx, epsilon: 1));

        // And both are in the middle of the pane, not of the window.
        final paneLeft = window.size.width - window.paneWidth;
        expect(
          face.dx,
          moreOrLessEquals(paneLeft + window.paneWidth / 2, epsilon: 1),
        );
      });
    }

    testWidgets('and is drawn at the profile size, round', (tester) async {
      await harness.pump(tester, profile: kAda, window: PaneWindow.desktop);

      expect(
        tester.getSize(avatar()),
        Size.square(ChatAvatarSize.xxl.diameter),
      );
    });
  });

  group('on a wide pane', () {
    testWidgets('the content keeps to a centred column', (tester) async {
      await harness.pump(
        tester,
        profile: kAda,
        window: PaneWindow.desktop,
        directChatId: kProfileChatId,
      );

      const window = PaneWindow.desktop;
      final paneLeft = window.size.width - window.paneWidth;
      final card = tester.getRect(
        find
            .ancestor(of: find.text('@ada'), matching: find.byType(Material))
            .first,
      );
      final tabs = tester.getRect(find.byType(TabBar));

      // The 720 px column, less the card's own margins, in the middle.
      expect(tabs.width, AppContentWidths.profile);
      expect(
        tabs.center.dx,
        moreOrLessEquals(paneLeft + window.paneWidth / 2, epsilon: 1),
      );
      expect(card.width, AppContentWidths.profile - AppSpacing.x4 * 2);
    });

    testWidgets('the round buttons stay a row, not the pane\'s width', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda, window: PaneWindow.desktop);

      final write = tester.getCenter(find.text('Написать'));
      final more = tester.getCenter(find.text('Ещё'));
      expect(more.dx - write.dx, QuickActionSizes.slot * 3);
    });
  });

  testWidgets('the camera keeps clear of the name', (tester) async {
    await harness.pump(
      tester,
      profile: kMaria,
      profileId: null,
      window: PaneWindow.phone,
    );

    final camera = tester.getRect(find.byTooltip('Сменить фото'));
    final name = tester.getRect(find.text('Мария Иванова'));
    expect(camera.bottom, lessThan(name.top));
  });

  /// The four profiles a reader meets, as they would meet them.
  final cases =
      <
        String,
        ({
          ProfileEntity profile,
          int? profileId,
          Contact? contact,
          String? chatId,
          bool? online,
          bool blocked,
        })
      >{
        // In the book, with a chat: the saved name, "last seen recently",
        // the chat's media at the foot.
        'contact': (
          profile: kAda,
          profileId: kProfileOther,
          contact: kAdaInBook,
          chatId: kProfileChatId,
          online: false,
          blocked: false,
        ),
        // A stranger from a group: no chat, so nothing to say about
        // presence and nothing to silence.
        'stranger': (
          profile: kGrace,
          profileId: kProfileOther,
          contact: null,
          chatId: null,
          online: null,
          blocked: false,
        ),
        // Blocked: the notice with its way back, and no call.
        'blocked': (
          profile: kAda,
          profileId: kProfileOther,
          contact: null,
          chatId: kProfileChatId,
          online: true,
          blocked: true,
        ),
        'own': (
          profile: kMaria,
          profileId: null,
          contact: null,
          chatId: null,
          online: null,
          blocked: false,
        ),
      };

  group('the QR sheet', () {
    for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
      for (final theme in {'light': false, 'dark': true}.entries) {
        testGoldens('${window.name}, ${theme.key}', (tester) async {
          await harness.pump(
            tester,
            profile: kAda,
            contact: kAdaInBook,
            window: window,
            dark: theme.value,
          );

          await tester.longPress(find.text('@ada'));
          await tester.pumpAndSettle();

          await screenMatchesGolden(
            tester,
            'profile_qr_${window.name}_${theme.key}',
          );
        });
      }
    }
  });

  group('goldens', () {
    for (final entry in cases.entries) {
      for (final window in [PaneWindow.phone, PaneWindow.desktop]) {
        for (final theme in {'light': false, 'dark': true}.entries) {
          testGoldens('${entry.key}, ${window.name}, ${theme.key}', (
            tester,
          ) async {
            final setup = entry.value;
            await harness.pump(
              tester,
              profile: setup.profile,
              profileId: setup.profileId,
              contact: setup.contact,
              directChatId: setup.chatId,
              online: setup.online,
              blocked: setup.blocked,
              window: window,
              dark: theme.value,
            );

            await screenMatchesGolden(
              tester,
              'profile_${entry.key}_${window.name}_${theme.key}',
            );
          });
        }
      }
    }
  });
}
