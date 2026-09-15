import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_pages.dart';
import 'package:chatix/features/chat/domain/usecases/get_chats_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/update_chat_state_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/data/models/chat_folder_model.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

class MockGetChatsUseCase extends Mock implements GetChatsUseCase {}

class MockUpdateChatStateUseCase extends Mock
    implements UpdateChatStateUseCase {}

class _FakeAuthController extends AuthController {
  @override
  Future<UserEntity?> build() async =>
      const UserEntity(id: 7, username: 'me', email: 'me@example.com');
}

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';

  setUpAll(() {
    dotenv.testLoad(fileInput: 'BASE_URL=https://api.example.com');
  });

  late InMemoryChatOrganizerDataSource store;
  late FakeWebSocketChannel channel;
  late ChatSocketService socket;
  late MockGetChatsUseCase getChats;
  late MockUpdateChatStateUseCase updateState;

  /// What `GET /chats/?archived=true` answers with.
  late List<ChatEntity> archivedChats;

  ChatEntity archivedChat(String id) => ChatEntity(
    id: id,
    seqCounter: 4,
    lastActivityAt: DateTime.utc(2026, 3, 10),
    type: ChatType.group,
    name: 'Chat $id',
    description: null,
    avatarS3Key: null,
    isPublic: false,
    adminOnly: false,
    slowModeSeconds: 0,
    permissions: const {},
    createdBy: 1,
    memberCount: 2,
    state: const ChatStateEntity(isArchived: true),
  );

  setUp(() {
    store = InMemoryChatOrganizerDataSource();
    getChats = MockGetChatsUseCase();
    updateState = MockUpdateChatStateUseCase();
    archivedChats = <ChatEntity>[];

    when(
      () => getChats.execute(
        limit: any(named: 'limit'),
        archived: any(named: 'archived'),
      ),
    ).thenAnswer(
      (invocation) async => Right(
        ChatsPage(
          chats: (invocation.namedArguments[#archived] as bool)
              ? archivedChats
              : const [],
          hasNext: false,
          nextDate: null,
          nextChatId: null,
        ),
      ),
    );

    when(
      () => updateState.setArchived(any(), archived: any(named: 'archived')),
    ).thenAnswer((_) async => const Right(ChatStateEntity()));
    channel = FakeWebSocketChannel();
    socket = ChatSocketService(
      secureStorage: FakeSecureStorageService(
        initialValues: {AppConstants.accessTokenKey: 'token'},
      ),
      channelFactory: (_) => channel,
    );
  });

  tearDown(() async {
    await socket.dispose();
    await channel.dispose();
  });

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(
      overrides: [
        chatOrganizerDataSourceProvider.overrideWithValue(store),
        chatSocketServiceProvider.overrideWithValue(socket),
        authProvider.overrideWith(_FakeAuthController.new),
        getChatsUseCaseProvider.overrideWithValue(getChats),
        updateChatStateUseCaseProvider.overrideWithValue(updateState),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authProvider.future);
    await container.read(chatOrganizerProvider.future);
    await socket.connect();

    return container;
  }

  Map<String, dynamic> newMessage({
    required int senderId,
    String eventId = 'evt-1',
  }) => {
    'type': 'new_message',
    'channel': chatId,
    'payload': {
      'event_id': eventId,
      'event_name': 'chats.message.new',
      'event': {
        'message_id': 'm-1',
        'seq': 4,
        'sender_id': senderId,
        'message_type': 'text',
      },
      'message': {
        'id': 'm-1',
        'chat_id': chatId,
        'seq': 4,
        'author_id': senderId,
        'type': 'text',
        'content': 'knock knock',
        'created_at': '2026-03-10T10:00:00Z',
        'is_edited': false,
      },
    },
    'ts': '2026-03-10T10:00:00Z',
  };

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('what the store held is what the folders start from', () async {
    store = InMemoryChatOrganizerDataSource(
      folders: [ChatFolderModel.fromEntity(ChatFolder.fromPreset(FolderPreset.unread))],
    );

    final container = await boot();

    expect(container.read(organizerDataProvider).folders, hasLength(1));
  });

  test('a message from someone else brings an archived chat back', () async {
    archivedChats = [archivedChat(chatId)];

    final container = await boot();
    // The archive is only known to a device that has fetched it.
    await container.read(archivedChatListProvider.future);

    channel.emit(newMessage(senderId: 9));
    await settle();

    verify(() => updateState.setArchived(chatId, archived: false)).called(1);
  });

  test('my own message leaves the chat where I put it', () async {
    archivedChats = [archivedChat(chatId)];

    final container = await boot();
    await container.read(archivedChatListProvider.future);

    channel.emit(newMessage(senderId: 7));
    await settle();

    verifyNever(
      () => updateState.setArchived(any(), archived: any(named: 'archived')),
    );
  });

  test('a message in a chat nobody archived changes nothing', () async {
    final container = await boot();
    await container.read(archivedChatListProvider.future);

    channel.emit(newMessage(senderId: 9));
    await settle();

    verifyNever(
      () => updateState.setArchived(any(), archived: any(named: 'archived')),
    );
  });

  test('with the setting off the archive stays closed', () async {
    archivedChats = [archivedChat(chatId)];

    final container = await boot();
    await container.read(archivedChatListProvider.future);

    await container
        .read(chatOrganizerProvider.notifier)
        .setUnarchiveOnNewMessage(enabled: false);

    channel.emit(newMessage(senderId: 9));
    await settle();

    verifyNever(
      () => updateState.setArchived(any(), archived: any(named: 'archived')),
    );
  });

  test('a deleted folder takes the tab selection with it', () async {
    final container = await boot();
    final organizer = container.read(chatOrganizerProvider.notifier);
    final preset = FolderPreset.unread;

    await organizer.saveFolder(ChatFolder.fromPreset(preset));
    container.read(activeFolderProvider.notifier).select(preset.folderId);

    expect(container.read(activeFolderProvider), preset.folderId);

    await organizer.deleteFolder(preset.folderId);

    expect(container.read(activeFolderProvider), isNull);
    expect(container.read(activeChatFolderProvider), isNull);
  });

  test(
    'the selected tab survives the list being reorganised around it',
    () async {
      final container = await boot();
      final organizer = container.read(chatOrganizerProvider.notifier);
      const preset = FolderPreset.groups;

      await organizer.saveFolder(ChatFolder.fromPreset(preset));
      container.read(activeFolderProvider.notifier).select(preset.folderId);

      // Saving a folder rewrites the organizer's state, which the selection
      // is computed from; it must not take the chosen tab down with it.
      await organizer.saveFolder(ChatFolder.fromPreset(FolderPreset.personal));

      expect(container.read(activeFolderProvider), preset.folderId);
      expect(container.read(activeChatFolderProvider)?.preset, preset);
    },
  );
}
