import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/features/chat/presentation/utils/chat_shared_content.dart';
import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';
import 'package:chatix/features/profile/presentation/utils/profile_view.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';
import 'package:chatix/gen/l10n/app_localizations_ru.dart';

import '../../../../helpers/profile_screen_harness.dart';

void main() {
  final en = AppLocalizationsEn();
  final ru = AppLocalizationsRu();

  setUpAll(ProfileScreenHarness.setUpAll);

  late ProfileScreenHarness harness;
  late List<String> clipboard;

  setUp(() {
    harness = ProfileScreenHarness();
    clipboard = [];
  });

  void captureClipboard(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }

  /// Lets every snackbar run out, so no timer outlives the test.
  Future<void> drainSnackbars(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  }

  Future<void> openMore(WidgetTester tester) async {
    await tester.tap(find.text(ru.profileActionMore));
    await tester.pumpAndSettle();
  }

  group("somebody else's profile", () {
    testWidgets('lays the facts out as rows, each over its caption', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda);

      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('@ada'), findsOneWidget);
      expect(find.text(ru.username), findsOneWidget);
      expect(find.text(kAda.bio!), findsOneWidget);
      expect(find.text(ru.profileAbout), findsOneWidget);
      // Day and month, the age for the year — no year, no weekday.
      expect(find.text('12 апреля (36 лет)'), findsOneWidget);
      expect(find.text(ru.profileBirthday), findsOneWidget);
      expect(find.text('ada-l'), findsOneWidget);
      expect(find.text('Github'), findsOneWidget);
      expect(find.text('Telegram'), findsOneWidget);
    });

    testWidgets('leaves the template\'s specialization and skills out', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda);

      expect(find.text('Analytical engines'), findsNothing);
      expect(find.text(ru.specialization), findsNothing);
      expect(find.text('math'), findsNothing);
      expect(find.text(ru.profileSkills), findsNothing);
    });

    testWidgets('offers write, call, mute and more — never edit', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda);

      expect(find.text(ru.sendMessageAction), findsOneWidget);
      expect(find.text(ru.callTitle), findsOneWidget);
      expect(find.text(ru.profileActionMute), findsOneWidget);
      expect(find.text(ru.profileActionMore), findsOneWidget);
      expect(find.text(ru.profileEditAction), findsNothing);
    });

    testWidgets('goes by the name the reader saved them under', (tester) async {
      await harness.pump(tester, profile: kAda, contact: kAdaInBook);

      expect(find.text('Ада из клуба'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
    });

    testWidgets('falls back to the handle when there is no name', (
      tester,
    ) async {
      await harness.pump(tester, profile: kGrace.copyWith(displayName: ''));

      // The title and the username row both say it.
      expect(find.text('@grace'), findsNWidgets(2));
    });

    testWidgets('an empty profile says so rather than showing blanks', (
      tester,
    ) async {
      await harness.pump(
        tester,
        profile: kGrace.copyWith(bio: '  '),
        locale: const Locale('en'),
      );

      expect(find.text(en.profileEmptyHintOther), findsOneWidget);
      expect(find.text(en.profileAbout), findsNothing);
    });
  });

  group('presence', () {
    testWidgets('online, in the accent, read off the direct chat', (
      tester,
    ) async {
      await harness.pump(
        tester,
        profile: kAda,
        directChatId: kProfileChatId,
        online: true,
      );

      expect(find.text(ru.chatStatusOnline), findsOneWidget);
      final style = tester.widget<Text>(find.text(ru.chatStatusOnline)).style;
      expect(
        style?.color,
        Theme.of(tester.element(find.text('Ada Lovelace'))).colorScheme.primary,
      );
    });

    testWidgets('"last seen recently" when the chat says they are away', (
      tester,
    ) async {
      await harness.pump(
        tester,
        profile: kAda,
        directChatId: kProfileChatId,
        online: false,
      );

      expect(find.text(ru.profileStatusRecently), findsOneWidget);
    });

    testWidgets('nothing at all with no chat to read it from', (tester) async {
      await harness.pump(tester, profile: kAda);

      expect(find.text(ru.chatStatusOnline), findsNothing);
      expect(find.text(ru.profileStatusRecently), findsNothing);
      // Presence costs a request; a profile with no chat makes none.
      verifyNever(
        () => harness.getMembers.execute(
          any(),
          limit: any(named: 'limit'),
          includePresence: any(named: 'includePresence'),
        ),
      );
    });
  });

  group('the username row', () {
    testWidgets('a tap copies the handle', (tester) async {
      captureClipboard(tester);
      await harness.pump(tester, profile: kAda);

      await tester.tap(find.text('@ada'));
      await tester.pumpAndSettle();

      expect(clipboard, ['@ada']);
      expect(find.text(ru.profileUsernameCopied), findsOneWidget);
      await drainSnackbars(tester);
    });

    testWidgets('a long press shows the QR code of the profile link', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda);

      await tester.longPress(find.text('@ada'));
      await tester.pumpAndSettle();

      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr, isNotNull);
      expect(find.text(ru.profileQrHint), findsOneWidget);
      expect(find.text(ru.profileCopyLink), findsOneWidget);
    });

    testWidgets('the QR sheet copies the link', (tester) async {
      captureClipboard(tester);
      await harness.pump(tester, profile: kAda);

      await tester.tap(find.byTooltip(ru.profileActionQr));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.profileCopyLink));
      await tester.pumpAndSettle();

      expect(clipboard, [ProfileShareLink.of(kProfileOther)]);
      await drainSnackbars(tester);
    });
  });

  group('mute', () {
    testWidgets('is greyed out while there is no chat to silence', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda);

      await tester.tap(find.text(ru.profileActionMute));
      await tester.pumpAndSettle();

      expect(find.text(ru.muteForHour), findsNothing);
    });

    testWidgets('asks for how long, then silences the direct chat', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda, directChatId: kProfileChatId);

      await tester.tap(find.text(ru.profileActionMute));
      await tester.pumpAndSettle();
      await tester.tap(find.text(ru.muteForHour));
      await tester.pumpAndSettle();

      final mute = harness.stateActions!.mutes.single;
      expect(mute.chatId, kProfileChatId);
      expect(mute.muted, isTrue);
      expect(mute.until, isNotNull);
      await drainSnackbars(tester);
    });

    testWidgets('a silenced chat is let speak again at once', (tester) async {
      await harness.pump(
        tester,
        profile: kAda,
        directChatId: kProfileChatId,
        muted: true,
      );

      await tester.tap(find.text(ru.profileActionUnmute));
      await tester.pumpAndSettle();

      final mute = harness.stateActions!.mutes.single;
      expect(mute.muted, isFalse);
      await drainSnackbars(tester);
    });
  });

  group('more', () {
    testWidgets('someone not in the book: share, add, block', (tester) async {
      await harness.pump(tester, profile: kAda);
      await openMore(tester);

      expect(find.text(ru.profileShareContact), findsOneWidget);
      expect(find.text(ru.profileAddToContacts), findsOneWidget);
      expect(find.text(ru.blockUserAction), findsOneWidget);
      expect(find.text(ru.contactsRemoveFromContacts), findsNothing);
    });

    testWidgets('a contact: share, rename, remove, block', (tester) async {
      await harness.pump(tester, profile: kAda, contact: kAdaInBook);
      await openMore(tester);

      expect(find.text(ru.profileShareContact), findsOneWidget);
      expect(find.text(ru.contactsActionRename), findsOneWidget);
      expect(find.text(ru.contactsRemoveFromContacts), findsOneWidget);
      expect(find.text(ru.profileAddToContacts), findsNothing);
    });

    testWidgets('share falls back to the clipboard without a share sheet', (
      tester,
    ) async {
      captureClipboard(tester);
      await harness.pump(tester, profile: kAda);
      await openMore(tester);

      await tester.tap(find.text(ru.profileShareContact));
      await tester.pumpAndSettle();

      expect(
        clipboard.single,
        ProfileShareLink.messageFor(
          kProfileOther,
          displayName: 'Ada Lovelace',
          username: 'ada',
        ),
      );
      await drainSnackbars(tester);
    });

    testWidgets('block asks, blocks, and the page says so', (tester) async {
      await harness.pump(tester, profile: kAda);
      await openMore(tester);

      await tester.tap(find.text(ru.blockUserAction));
      await tester.pumpAndSettle();
      expect(find.text(ru.blockUserTitle('Ada Lovelace')), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, ru.blockUserConfirm));
      await tester.pumpAndSettle();

      expect(harness.blocks.blocks, [kProfileOther]);
      expect(find.text(ru.profileBlockedNotice), findsOneWidget);
      await drainSnackbars(tester);

      // The menu now offers the way back.
      await openMore(tester);
      final menu = find.byType(PopupMenuItem<ProfileMenuAction>);
      expect(
        find.descendant(of: menu, matching: find.text(ru.unblockUserAction)),
        findsOneWidget,
      );
      expect(find.text(ru.blockUserAction), findsNothing);
    });
  });

  group('someone blocked', () {
    testWidgets('carries the notice, and its button unblocks', (tester) async {
      await harness.pump(tester, profile: kAda, blocked: true);

      expect(find.text(ru.profileBlockedNotice), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, ru.unblockUserAction));
      await tester.pumpAndSettle();

      expect(harness.blocks.unblocks, [kProfileOther]);
      expect(find.text(ru.profileBlockedNotice), findsNothing);
      await drainSnackbars(tester);
    });

    testWidgets('cannot be called', (tester) async {
      await harness.pump(
        tester,
        profile: kAda,
        blocked: true,
        directChatId: kProfileChatId,
      );

      await tester.tap(find.text(ru.callTitle));
      await tester.pumpAndSettle();

      expect(harness.visited, isEmpty);
    });
  });

  group('the direct chat', () {
    testWidgets('its shared media hang off the foot of the page', (
      tester,
    ) async {
      await harness.pump(tester, profile: kAda, directChatId: kProfileChatId);

      await tester.scrollUntilVisible(
        find.text(ru.sharedVoice),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(ru.sharedFiles), findsOneWidget);
      expect(find.text(ru.sharedLinks), findsOneWidget);
      expect(find.text(ru.sharedVoice), findsOneWidget);
      expect(SharedContentTab.values, hasLength(4));
    });

    testWidgets('no chat, no tabs', (tester) async {
      await harness.pump(tester, profile: kAda);

      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('a call goes straight to the chat this page belongs to', (
      tester,
    ) async {
      await harness.pump(
        tester,
        profile: kAda,
        directChatId: kProfileChatId,
        openedFromChat: true,
      );

      await tester.tap(find.text(ru.callTitle));
      await tester.pumpAndSettle();

      expect(
        harness.visited,
        contains(ChatCallRoute.locationOf(kProfileChatId)),
      );
    });

    testWidgets('"message" goes back to that chat', (tester) async {
      await harness.pump(
        tester,
        profile: kAda,
        directChatId: kProfileChatId,
        openedFromChat: true,
      );

      await tester.tap(find.text(ru.sendMessageAction));
      await tester.pumpAndSettle();

      expect(
        harness.visited,
        contains(ChatDetailRoute(kProfileChatId).location),
      );
    });
  });

  group('my own profile', () {
    testWidgets('has "Edit" in the bar, share and QR, no write or call', (
      tester,
    ) async {
      await harness.pump(tester, profile: kMaria, profileId: null);

      expect(find.widgetWithText(TextButton, ru.profileEditAction), findsOne);
      expect(find.text(ru.profileShareAction), findsOneWidget);
      expect(find.text(ru.profileActionQr), findsOneWidget);
      expect(find.text(ru.sendMessageAction), findsNothing);
      expect(find.text(ru.callTitle), findsNothing);
      expect(find.text(ru.profileActionMute), findsNothing);
    });

    testWidgets('"Edit" opens the form', (tester) async {
      await harness.pump(tester, profile: kMaria, profileId: null);

      await tester.tap(find.widgetWithText(TextButton, ru.profileEditAction));
      await tester.pumpAndSettle();

      expect(harness.visited, contains(ProfileEditRoute.location));
    });

    testWidgets('is always online, and carries the camera', (tester) async {
      await harness.pump(tester, profile: kMaria, profileId: null);

      expect(find.text(ru.chatStatusOnline), findsOneWidget);
      expect(find.byTooltip(ru.changePhoto), findsOneWidget);
    });

    testWidgets('shows the address only its owner can see', (tester) async {
      await harness.pump(tester, profile: kMaria, profileId: null);

      expect(find.text('maria@example.com'), findsOneWidget);
      expect(find.text(ru.email), findsOneWidget);
    });

    testWidgets('carries the settings and devices rows', (tester) async {
      await harness.pump(tester, profile: kMaria, profileId: null);

      await tester.scrollUntilVisible(
        find.text(ru.myDevices),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(ru.settings), findsOneWidget);
      expect(find.text(ru.settingsRowHint), findsOneWidget);
      // `GET /users/sessions/` is a bare array, so the count is its length.
      expect(find.text(ru.devicesCount(2)), findsOneWidget);
    });

    testWidgets('lays out in the dark theme without overflowing', (
      tester,
    ) async {
      await harness.pump(tester, profile: kMaria, profileId: null, dark: true);

      expect(tester.takeException(), isNull);
      expect(find.text('Мария Иванова'), findsOneWidget);
    });
  });
}
