import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/constants/app_constants.dart';
import 'package:chatix/core/websocket/chat_socket_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat_organizer/data/datasources/chat_organizer_local_data_source.dart';
import 'package:chatix/features/chat_organizer/domain/entities/chat_folder.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_preset.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_failures.dart';
import 'package:chatix/features/chat_organizer/domain/entities/organizer_settings.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_provider.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/chat_organizer_providers.dart';
import 'package:chatix/features/chat_organizer/presentation/providers/folder_selection_provider.dart';

import '../../../../helpers/fakes/fake_secure_storage_service.dart';
import '../../../../helpers/fakes/fake_web_socket_channel.dart';

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

  setUp(() {
    store = InMemoryChatOrganizerDataSource();
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

  test('what the store held is what the list starts from', () async {
    store = InMemoryChatOrganizerDataSource(
      pinned: {'a'},
      archived: {'b'},
    );

    final container = await boot();
    final data = container.read(organizerDataProvider);

    expect(data.isPinned('a'), isTrue);
    expect(data.isArchived('b'), isTrue);
  });

  test('the pinned limit reaches the caller as a failure it can explain',
      () async {
    final container = await boot();
    final organizer = container.read(chatOrganizerProvider.notifier);

    for (var i = 0; i < OrganizerLimits.pinnedChats; i++) {
      expect(await organizer.setPinned('chat-$i', pinned: true), isNull);
    }

    final failure = await organizer.setPinned('one-too-many', pinned: true);

    expect(failure, isA<PinLimitFailure>());
    expect(container.read(organizerDataProvider).isPinned('one-too-many'),
        isFalse);
  });

  test('a message from someone else brings an archived chat back', () async {
    store = InMemoryChatOrganizerDataSource(archived: {chatId});
    final container = await boot();

    channel.emit(newMessage(senderId: 9));
    await settle();

    expect(container.read(organizerDataProvider).isArchived(chatId), isFalse);
  });

  test('my own message leaves the chat where I put it', () async {
    store = InMemoryChatOrganizerDataSource(archived: {chatId});
    final container = await boot();

    channel.emit(newMessage(senderId: 7));
    await settle();

    expect(container.read(organizerDataProvider).isArchived(chatId), isTrue);
  });

  test('with the setting off the archive stays closed', () async {
    final container = await boot();
    final organizer = container.read(chatOrganizerProvider.notifier);

    await organizer.setUnarchiveOnNewMessage(enabled: false);
    await organizer.setArchived(chatId, archived: true);

    channel.emit(newMessage(senderId: 9));
    await settle();

    expect(container.read(organizerDataProvider).isArchived(chatId), isTrue);
    expect(
      container.read(organizerDataProvider).settings,
      const OrganizerSettings(unarchiveOnNewMessage: false),
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

  test('the selected tab survives the list being reorganised around it', () async {
    final container = await boot();
    final organizer = container.read(chatOrganizerProvider.notifier);
    const preset = FolderPreset.groups;

    await organizer.saveFolder(ChatFolder.fromPreset(preset));
    container.read(activeFolderProvider.notifier).select(preset.folderId);

    // Pinning rewrites the organizer's state, which the selection is
    // computed from; it must not take the chosen tab down with it.
    await organizer.setPinned('some-chat', pinned: true);

    expect(container.read(activeFolderProvider), preset.folderId);
    expect(container.read(activeChatFolderProvider)?.preset, preset);
  });
}
