import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_attachment_use_case.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/chat/data/repositories/chat_repository_impl.dart';
import 'package:chatix/features/chat/domain/usecases/add_member_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/ban_member_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/change_member_role_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/delete_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/delete_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/edit_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/forward_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_attachment_download_url_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_members_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_context_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/get_messages_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/join_call_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/join_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/kick_member_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/leave_chat_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mark_read_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mute_call_participant_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/send_message_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_use_case.dart';

/// Dependency wiring for the chat feature's **REST** half (api-docs §6).
///
/// `chatRepositoryProvider` lives next to its implementation
/// (`data/repositories/chat_repository_impl.dart`) and
/// `chatRestDataSourceProvider` next to its own, matching how the profile and
/// project features are wired; this file only assembles the use cases on top.
///
/// The WebSocket layer (api-docs §7) brings its own providers for the socket
/// data source and message stream — deliberately kept separate so that a
/// screen doing plain history/pagination never instantiates a live connection.

// ─────────────────────────── Chats (§6.2) ───────────────────────────

final getChatsUseCaseProvider = Provider<GetChatsUseCase>((ref) {
  return GetChatsUseCase(ref.watch(chatRepositoryProvider));
});

final getChatUseCaseProvider = Provider<GetChatUseCase>((ref) {
  return GetChatUseCase(ref.watch(chatRepositoryProvider));
});

final createChatUseCaseProvider = Provider<CreateChatUseCase>((ref) {
  return CreateChatUseCase(ref.watch(chatRepositoryProvider));
});

final updateChatUseCaseProvider = Provider<UpdateChatUseCase>((ref) {
  return UpdateChatUseCase(ref.watch(chatRepositoryProvider));
});

final deleteChatUseCaseProvider = Provider<DeleteChatUseCase>((ref) {
  return DeleteChatUseCase(ref.watch(chatRepositoryProvider));
});

final joinChatUseCaseProvider = Provider<JoinChatUseCase>((ref) {
  return JoinChatUseCase(ref.watch(chatRepositoryProvider));
});

final leaveChatUseCaseProvider = Provider<LeaveChatUseCase>((ref) {
  return LeaveChatUseCase(ref.watch(chatRepositoryProvider));
});

// ────────────────────────── Members (§6.3) ──────────────────────────

final getMembersUseCaseProvider = Provider<GetMembersUseCase>((ref) {
  return GetMembersUseCase(ref.watch(chatRepositoryProvider));
});

final addMemberUseCaseProvider = Provider<AddMemberUseCase>((ref) {
  return AddMemberUseCase(ref.watch(chatRepositoryProvider));
});

final changeMemberRoleUseCaseProvider = Provider<ChangeMemberRoleUseCase>((
  ref,
) {
  return ChangeMemberRoleUseCase(ref.watch(chatRepositoryProvider));
});

final banMemberUseCaseProvider = Provider<BanMemberUseCase>((ref) {
  return BanMemberUseCase(ref.watch(chatRepositoryProvider));
});

final kickMemberUseCaseProvider = Provider<KickMemberUseCase>((ref) {
  return KickMemberUseCase(ref.watch(chatRepositoryProvider));
});

// ───────────────────────── Messages (§6.4) ──────────────────────────

final getMessagesUseCaseProvider = Provider<GetMessagesUseCase>((ref) {
  return GetMessagesUseCase(ref.watch(chatRepositoryProvider));
});

final getMessagesContextUseCaseProvider = Provider<GetMessagesContextUseCase>((
  ref,
) {
  return GetMessagesContextUseCase(ref.watch(chatRepositoryProvider));
});

final getMessageUseCaseProvider = Provider<GetMessageUseCase>((ref) {
  return GetMessageUseCase(ref.watch(chatRepositoryProvider));
});

final sendMessageUseCaseProvider = Provider<SendMessageUseCase>((ref) {
  return SendMessageUseCase(ref.watch(chatRepositoryProvider));
});

final editMessageUseCaseProvider = Provider<EditMessageUseCase>((ref) {
  return EditMessageUseCase(ref.watch(chatRepositoryProvider));
});

final deleteMessageUseCaseProvider = Provider<DeleteMessageUseCase>((ref) {
  return DeleteMessageUseCase(ref.watch(chatRepositoryProvider));
});

final forwardMessageUseCaseProvider = Provider<ForwardMessageUseCase>((ref) {
  return ForwardMessageUseCase(ref.watch(chatRepositoryProvider));
});

final markReadUseCaseProvider = Provider<MarkReadUseCase>((ref) {
  return MarkReadUseCase(ref.watch(chatRepositoryProvider));
});

// ──────────────────────── Attachments (§6.5) ────────────────────────

/// Drives all three upload requests (and the client-side limit checks) — see
/// [UploadChatAttachmentUseCase]. Note it needs *two* dependencies: the
/// repository for steps 1/3 and the bare-Dio uploader for the raw PUT.
final uploadChatAttachmentUseCaseProvider =
    Provider<UploadChatAttachmentUseCase>((ref) {
      return UploadChatAttachmentUseCase(
        ref.watch(chatRepositoryProvider),
        ref.watch(chatAttachmentUploaderProvider),
      );
    });

final getAttachmentDownloadUrlUseCaseProvider =
    Provider<GetAttachmentDownloadUrlUseCase>((ref) {
      return GetAttachmentDownloadUrlUseCase(ref.watch(chatRepositoryProvider));
    });

// ─────────────────────────── Calls (§6.6) ───────────────────────────

final joinCallUseCaseProvider = Provider<JoinCallUseCase>((ref) {
  return JoinCallUseCase(ref.watch(chatRepositoryProvider));
});

final muteCallParticipantUseCaseProvider = Provider<MuteCallParticipantUseCase>(
  (ref) {
    return MuteCallParticipantUseCase(ref.watch(chatRepositoryProvider));
  },
);