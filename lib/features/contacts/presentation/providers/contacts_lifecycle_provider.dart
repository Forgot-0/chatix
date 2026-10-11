import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/contacts/domain/entities/contact_import.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';

/// The last background import the server finished, until a screen has said
/// so — `contacts_import_completed` (api-docs §4.13).
class ContactImportReportController extends Notifier<ContactImportReport?> {
  @override
  ContactImportReport? build() => null;

  void report(ContactImportReport report) => state = report;

  void clear() => state = null;
}

final contactImportReportProvider =
    NotifierProvider<ContactImportReportController, ContactImportReport?>(
      ContactImportReportController.new,
    );

/// Keeps the book in step with the session, from the top of the app.
///
/// * Signed in — at launch or by signing in — it syncs, so local names are
///   on the chat list without the contacts tab ever being opened. A first
///   sign-in on this device finds no book and reads the whole list.
/// * Signed out, it throws the book away: it is one account's, and the next
///   account must not see its names.
/// * A queued import finishing arrives over the socket with counts only, so
///   it syncs again to pick up the new rows, and leaves the counts for the
///   contacts tab to announce.
final contactsLifecycleProvider = Provider<void>((ref) {
  var wasSignedIn = ref.read(authProvider).value != null;

  void sync() => unawaited(ref.read(contactsProvider.notifier).sync());

  // Not during this build: a provider may not change another while it is
  // being created.
  if (wasSignedIn) scheduleMicrotask(sync);

  ref.listen(authProvider, (_, next) {
    if (next.isLoading) return;

    final signedIn = next.hasValue && next.value != null;
    final signedOut = wasSignedIn && !signedIn;
    final signedInNow = !wasSignedIn && signedIn;
    wasSignedIn = signedIn;

    if (signedOut) {
      Logger.info('Contacts: signed out, forgetting the book');
      unawaited(ref.read(contactsProvider.notifier).forget());
    } else if (signedInNow) {
      sync();
    }
  });

  ref.listen(chatSocketEventsProvider, (_, next) {
    final event = next.value;
    if (event is! ContactsImportCompleted) return;
    if (event.ownerId != ref.read(authProvider).value?.id) return;

    ref
        .read(contactImportReportProvider.notifier)
        .report(
          ContactImportReport(
            ownerId: event.ownerId,
            accepted: event.accepted,
            matched: event.matched,
            pending: event.pending,
            invalid: event.invalid,
          ),
        );
    sync();
  });
}, dependencies: [authProvider, chatSocketEventsProvider]);

/// The 1:1 chat with each person, by their user id, among the chats this
/// device has loaded — the only place presence can be read from.
final directChatIdsProvider = Provider<Map<int, String>>((ref) {
  final myUserId = ref.watch(authProvider.select((user) => user.value?.id));
  final chats = ref.watch(
    chatListProvider.select((state) => state.value?.items),
  );
  if (chats == null) return const <int, String>{};

  return {
    for (final chat in chats)
      if (chat.type == ChatType.direct)
        if (chat.peerProfile(myUserId)?.userId case final int peer)
          peer: chat.id,
  };
});

/// Whether [userId] is online, when that can be known at all: presence only
/// ships with a chat's member list (api-docs §5.3), so only for people this
/// account has a direct chat with. Null means "do not say".
final contactOnlineProvider = Provider.family<bool?, int>((ref, userId) {
  final chatId = ref.watch(
    directChatIdsProvider.select((chats) => chats[userId]),
  );
  if (chatId == null) return null;
  return ref.watch(chatPeerOnlineProvider(chatId));
});
