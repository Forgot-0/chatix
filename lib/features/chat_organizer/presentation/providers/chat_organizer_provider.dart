import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/utils/logger.dart';
import 'package:chatix/core/websocket/ws_event.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_organizer_data.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';

/// Pins, the archive, the folders and the switches around them.
///
/// Every change goes through a use case, which is what enforces the pinned
/// limit and what keeps the archive and the pinned zone from claiming the
/// same chat. Nothing here talks to storage directly.
class ChatOrganizerController extends AsyncNotifier<ChatOrganizerData> {
  StreamSubscription<WSEvent>? _eventSubscription;

  @override
  Future<ChatOrganizerData> build() async {
    ref.onDispose(() {
      _eventSubscription?.cancel();
      _eventSubscription = null;
    });

    final result = await ref.read(loadOrganizerUseCaseProvider).execute();
    final data = result.getOrElse((failure) => throw failure);

    _watchForArchiveReturns();
    return data;
  }

  /// A chat somebody wrote into comes back out of the archive, when that is
  /// what the reader asked for. Messages I sent myself do not count: opening
  /// a chat to write in it is not the archive being wrong.
  void _watchForArchiveReturns() {
    _eventSubscription = ref
        .read(chatSocketServiceProvider)
        .events
        .listen(
          (event) {
            if (event is! NewMessage) return;

            final data = state.value;
            if (data == null) return;
            if (!data.settings.unarchiveOnNewMessage) return;
            if (!data.isArchived(event.chatId)) return;

            final myUserId = ref.read(authProvider).value?.id;
            if (myUserId != null && event.senderId == myUserId) return;

            unawaited(setArchived(event.chatId, archived: false));
          },
          onError: (Object error, StackTrace stackTrace) {
            Logger.error('Organizer: event stream error', error, stackTrace);
          },
          cancelOnError: false,
        );
  }

  /// Pins [chatId] or lets it go, and reports what stopped it — a full
  /// pinned zone, or storage that would not take the write.
  Future<Failure?> setPinned(String chatId, {required bool pinned}) {
    return _apply(
      (data) => ref
          .read(setChatPinnedUseCaseProvider)
          .execute(data, chatId: chatId, pinned: pinned),
    );
  }

  Future<Failure?> togglePin(String chatId) {
    final data = state.value;
    if (data == null) return Future.value(const CacheFailure());
    return setPinned(chatId, pinned: !data.isPinned(chatId));
  }

  Future<Failure?> setArchived(String chatId, {required bool archived}) {
    return _apply(
      (data) => ref
          .read(setChatArchivedUseCaseProvider)
          .execute(data, chatId: chatId, archived: archived),
    );
  }

  Future<Failure?> toggleArchived(String chatId) {
    final data = state.value;
    if (data == null) return Future.value(const CacheFailure());
    return setArchived(chatId, archived: !data.isArchived(chatId));
  }

  /// What deleting or leaving a chat means for state that only exists here.
  Future<Failure?> forget(String chatId) {
    return _apply(
      (data) => ref.read(forgetChatUseCaseProvider).execute(data, chatId),
    );
  }

  Future<Failure?> saveFolder(ChatFolder folder) {
    return _apply(
      (data) => ref.read(saveFolderUseCaseProvider).execute(data, folder),
    );
  }

  Future<Failure?> deleteFolder(String folderId) {
    return _apply(
      (data) => ref.read(deleteFolderUseCaseProvider).execute(data, folderId),
    );
  }

  Future<Failure?> reorderFolders({
    required int oldIndex,
    required int newIndex,
  }) {
    return _apply(
      (data) => ref
          .read(reorderFoldersUseCaseProvider)
          .execute(data, oldIndex: oldIndex, newIndex: newIndex),
    );
  }

  Future<Failure?> updateSettings(OrganizerSettings settings) {
    return _apply(
      (data) => ref
          .read(updateOrganizerSettingsUseCaseProvider)
          .execute(data, settings),
    );
  }

  Future<Failure?> setFoldersHidden({required bool hidden}) {
    final data = state.value;
    if (data == null) return Future.value(const CacheFailure());
    return updateSettings(data.settings.copyWith(foldersHidden: hidden));
  }

  Future<Failure?> setUnarchiveOnNewMessage({required bool enabled}) {
    final data = state.value;
    if (data == null) return Future.value(const CacheFailure());
    return updateSettings(
      data.settings.copyWith(unarchiveOnNewMessage: enabled),
    );
  }

  Future<Failure?> _apply(
    Future<Either<Failure, ChatOrganizerData>> Function(ChatOrganizerData data)
    action,
  ) async {
    final data = state.value;
    if (data == null) return const CacheFailure();

    final result = await action(data);

    return result.match((failure) => failure, (next) {
      if (ref.mounted && next != state.value) {
        state = AsyncValue.data(next);
      }
      return null;
    });
  }
}

final chatOrganizerProvider =
    AsyncNotifierProvider<ChatOrganizerController, ChatOrganizerData>(
      ChatOrganizerController.new,
    );

/// The organizer as the chat list reads it.
///
/// Local storage answers in a microtask and can only fail by being absent,
/// so the list does not need a loading state or an error state for it: an
/// account whose pins have not arrived yet simply has none for a frame.
final organizerDataProvider = Provider<ChatOrganizerData>(
  (ref) => ref.watch(chatOrganizerProvider).value ?? const ChatOrganizerData(),
);
