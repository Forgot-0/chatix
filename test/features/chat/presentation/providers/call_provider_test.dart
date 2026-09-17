import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:livekit_client/livekit_client.dart' show Room;
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/permissions/media_permissions.dart';
import 'package:chatix/features/chat/data/datasources/call_room_service.dart';
import 'package:chatix/features/chat/domain/entities/call_token_entity.dart';
import 'package:chatix/features/chat/domain/repositories/chat_repository.dart';
import 'package:chatix/features/chat/domain/usecases/join_call_use_case.dart';
import 'package:chatix/features/chat/domain/usecases/mute_call_participant_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/active_call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/call_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

class MockChatRepository extends Mock implements ChatRepository {}

/// A room service with no LiveKit behind it.
///
/// [room] stays null, which is exactly what the controller sees between a
/// connect and the first participant event, so the participant list is
/// empty throughout — these tests are about the state machine, not the roster.
class FakeCallRoomService implements CallRoomService {
  FakeCallRoomService({this.connectResult});

  final Either<Failure, Unit>? connectResult;

  final StreamController<CallRoomSignal> _signals =
      StreamController<CallRoomSignal>.broadcast();

  final List<bool> microphoneCalls = [];
  final List<bool> cameraCalls = [];
  final List<bool> speakerCalls = [];
  bool? connectedWithMicrophone;
  int disconnects = 0;

  void emit(CallRoomSignal signal) => _signals.add(signal);

  Future<void> close() => _signals.close();

  @override
  Room? get room => null;

  @override
  Stream<CallRoomSignal> get signals => _signals.stream;

  @override
  bool get canSwitchSpeaker => true;

  @override
  Future<Either<Failure, Unit>> connect(
    CallTokenEntity token, {
    required bool withMicrophone,
  }) async {
    connectedWithMicrophone = withMicrophone;
    return connectResult ?? const Right(unit);
  }

  @override
  Future<void> disconnect() async => disconnects++;

  @override
  Future<Either<Failure, Unit>> setCameraEnabled(bool enabled) async {
    cameraCalls.add(enabled);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setMicrophoneEnabled(bool enabled) async {
    microphoneCalls.add(enabled);
    return const Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> setSpeakerphoneEnabled(bool enabled) async {
    speakerCalls.add(enabled);
    return const Right(unit);
  }
}

class FakeMediaPermissions implements MediaPermissions {
  FakeMediaPermissions({
    this.microphone = MediaPermissionStatus.granted,
    this.camera = MediaPermissionStatus.granted,
  });

  MediaPermissionStatus microphone;
  MediaPermissionStatus camera;
  int settingsOpened = 0;
  final List<MediaDeviceKind> requested = [];

  @override
  Future<MediaPermissionStatus> check(MediaDeviceKind device) async =>
      device == MediaDeviceKind.microphone ? microphone : camera;

  @override
  Future<MediaPermissionStatus> request(MediaDeviceKind device) async {
    requested.add(device);
    return check(device);
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}

void main() {
  const chatId = 'a3f1c2d4-0000-4000-8000-000000000001';
  const otherChatId = 'a3f1c2d4-0000-4000-8000-000000000002';
  const token = CallTokenEntity(
    token: 'jwt',
    slug: 'room-slug',
    livekitUrl: 'wss://livekit.example',
  );

  late MockChatRepository repository;
  late FakeCallRoomService service;
  late FakeMediaPermissions permissions;

  setUp(() {
    repository = MockChatRepository();
    service = FakeCallRoomService();
    permissions = FakeMediaPermissions();
  });

  ProviderContainer boot({FakeCallRoomService? roomService}) {
    final room = roomService ?? service;
    final container = ProviderContainer(
      overrides: [
        callRoomServiceProvider.overrideWithValue(room),
        mediaPermissionsProvider.overrideWithValue(permissions),
        joinCallUseCaseProvider.overrideWithValue(JoinCallUseCase(repository)),
        muteCallParticipantUseCaseProvider.overrideWithValue(
          MuteCallParticipantUseCase(repository),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(room.close);
    return container;
  }

  void tokenAnswers() {
    when(
      () => repository.joinCall(any()),
    ).thenAnswer((_) async => const Right(token));
  }

  group('join', () {
    test('connects with the microphone once it has been granted', () async {
      tokenAnswers();
      final container = boot();

      await container.read(callProvider.notifier).join(chatId, chatName: 'Ops');
      final state = container.read(callProvider);

      expect(state.stage, CallStage.connected);
      expect(state.isLive, isTrue);
      expect(state.chatId, chatId);
      expect(state.chatName, 'Ops');
      expect(state.token, token);
      expect(state.isMicrophoneEnabled, isTrue);
      expect(state.connectedAt, isNotNull);
      expect(state.canSwitchSpeaker, isTrue);
      expect(state.permissionIssue, isNull);
      expect(service.connectedWithMicrophone, isTrue);
      expect(permissions.requested, [MediaDeviceKind.microphone]);
      expect(container.read(activeCallChatIdProvider), chatId);
      expect(container.read(isCallActiveProvider), isTrue);
    });

    test('a refused microphone joins muted and says so', () async {
      tokenAnswers();
      permissions.microphone = MediaPermissionStatus.permanentlyDenied;
      final container = boot();

      await container.read(callProvider.notifier).join(chatId);
      final state = container.read(callProvider);

      expect(state.stage, CallStage.connected);
      expect(state.isMicrophoneEnabled, isFalse);
      expect(service.connectedWithMicrophone, isFalse);
      expect(state.permissionIssue?.device, MediaDeviceKind.microphone);
      expect(state.permissionIssue?.isPermanent, isTrue);
    });

    test('a failed join token leaves the call idle with the failure', () async {
      when(() => repository.joinCall(any())).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'LIVEKIT_ERROR',
            message: '',
            detail: null,
            status: 502,
          ),
        ),
      );
      final container = boot();

      await container.read(callProvider.notifier).join(chatId);
      final state = container.read(callProvider);

      expect(state.stage, CallStage.idle);
      expect(state.failure, isA<ApiFailure>());
      expect(container.read(isCallActiveProvider), isFalse);
    });

    test('a failed LiveKit connect keeps the token but not the call', () async {
      tokenAnswers();
      final failing = FakeCallRoomService(
        connectResult: const Left(ServerFailure(message: 'no route')),
      );
      final container = boot(roomService: failing);

      await container.read(callProvider.notifier).join(chatId);
      final state = container.read(callProvider);

      expect(state.stage, CallStage.idle);
      expect(state.token, token);
      expect(state.failure, isA<ServerFailure>());
    });

    test('joining the call it is already in changes nothing', () async {
      tokenAnswers();
      final container = boot();

      await container.read(callProvider.notifier).join(chatId);
      await container.read(callProvider.notifier).join(chatId);

      verify(() => repository.joinCall(chatId)).called(1);
    });

    test('joining another chat leaves the first room first', () async {
      tokenAnswers();
      final container = boot();

      await container.read(callProvider.notifier).join(chatId);
      await container.read(callProvider.notifier).join(otherChatId);

      expect(service.disconnects, greaterThanOrEqualTo(1));
      expect(container.read(callProvider).chatId, otherChatId);
      expect(container.read(callProvider).isFor(chatId), isFalse);
    });
  });

  group('leaving', () {
    test('disconnects and clears the call', () async {
      tokenAnswers();
      final container = boot();

      await container.read(callProvider.notifier).join(chatId);
      await container.read(callProvider.notifier).leave();

      expect(service.disconnects, 1);
      expect(container.read(callProvider).stage, CallStage.idle);
      expect(container.read(callProvider).chatId, isNull);
      expect(container.read(isCallActiveProvider), isFalse);
    });
  });

  group('room signals', () {
    test('reconnecting keeps the call live, reconnected restores it', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      service.emit(CallRoomSignal.reconnecting);
      await pumpEventQueue();
      expect(container.read(callProvider).stage, CallStage.reconnecting);
      expect(container.read(callProvider).isLive, isTrue);
      expect(container.read(isCallActiveProvider), isTrue);

      service.emit(CallRoomSignal.reconnected);
      await pumpEventQueue();
      expect(container.read(callProvider).stage, CallStage.connected);
    });

    test('a dropped room ends the call without clearing the chat', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      service.emit(CallRoomSignal.disconnected);
      await pumpEventQueue();

      final state = container.read(callProvider);
      expect(state.stage, CallStage.disconnected);
      expect(state.participants, isEmpty);
      expect(state.isCameraEnabled, isFalse);
      expect(state.chatId, chatId);
      expect(container.read(isCallActiveProvider), isFalse);
    });

    test('signals after leaving are ignored', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);
      await container.read(callProvider.notifier).leave();

      service.emit(CallRoomSignal.disconnected);
      await pumpEventQueue();

      expect(container.read(callProvider).stage, CallStage.idle);
    });

    test('a dropped call can be dismissed back to the join prompt', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      service.emit(CallRoomSignal.disconnected);
      await pumpEventQueue();
      container.read(callProvider.notifier).dismissEndedCall();

      expect(container.read(callProvider).stage, CallStage.idle);
      expect(container.read(callProvider).chatId, isNull);
    });
  });

  group('device toggles', () {
    test('do nothing when there is no call', () async {
      final container = boot();

      await container.read(callProvider.notifier).toggleMicrophone();
      await container.read(callProvider.notifier).toggleCamera();
      await container.read(callProvider.notifier).toggleSpeakerphone();

      expect(service.microphoneCalls, isEmpty);
      expect(service.cameraCalls, isEmpty);
      expect(service.speakerCalls, isEmpty);
    });

    test('the microphone toggles both ways', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      await container.read(callProvider.notifier).toggleMicrophone();
      expect(service.microphoneCalls.last, isFalse);
      expect(container.read(callProvider).isMicrophoneEnabled, isFalse);

      await container.read(callProvider.notifier).toggleMicrophone();
      expect(service.microphoneCalls.last, isTrue);
      expect(container.read(callProvider).isMicrophoneEnabled, isTrue);
    });

    test('a refused camera is not published, and is explained', () async {
      tokenAnswers();
      permissions.camera = MediaPermissionStatus.denied;
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      await container.read(callProvider.notifier).toggleCamera();

      expect(service.cameraCalls, isEmpty);
      expect(container.read(callProvider).isCameraEnabled, isFalse);
      final issue = container.read(callProvider).permissionIssue;
      expect(issue?.device, MediaDeviceKind.camera);
      expect(issue?.isPermanent, isFalse);
    });

    test('granting the camera later clears its refusal', () async {
      tokenAnswers();
      permissions.camera = MediaPermissionStatus.denied;
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);
      await container.read(callProvider.notifier).toggleCamera();

      permissions.camera = MediaPermissionStatus.granted;
      await container.read(callProvider.notifier).toggleCamera();

      expect(service.cameraCalls, [true]);
      expect(container.read(callProvider).isCameraEnabled, isTrue);
      expect(container.read(callProvider).permissionIssue, isNull);
    });

    test('turning the camera off asks for nothing', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);
      await container.read(callProvider.notifier).toggleCamera();
      permissions.requested.clear();

      await container.read(callProvider.notifier).toggleCamera();

      expect(permissions.requested, isEmpty);
      expect(service.cameraCalls, [true, false]);
    });

    test('the speaker switches when the platform has one', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      await container.read(callProvider.notifier).toggleSpeakerphone();

      expect(service.speakerCalls, [true]);
      expect(container.read(callProvider).isSpeakerphoneEnabled, isTrue);
    });
  });

  group('layout', () {
    test('the layout control flips between the two modes', () async {
      final container = boot();

      expect(container.read(callProvider).layout, CallLayoutMode.grid);
      container.read(callProvider.notifier).toggleLayout();
      expect(container.read(callProvider).layout, CallLayoutMode.speaker);
      container.read(callProvider.notifier).toggleLayout();
      expect(container.read(callProvider).layout, CallLayoutMode.grid);
    });

    test('pinning someone switches to speaker view, tapping again unpins', () {
      final container = boot();

      container.read(callProvider.notifier).pinParticipant('7');
      expect(container.read(callProvider).pinnedIdentity, '7');
      expect(container.read(callProvider).layout, CallLayoutMode.speaker);

      container.read(callProvider.notifier).pinParticipant('7');
      expect(container.read(callProvider).pinnedIdentity, isNull);
    });

    test('the layout survives leaving the call', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);
      container.read(callProvider.notifier).toggleLayout();

      await container.read(callProvider.notifier).leave();

      expect(container.read(callProvider).layout, CallLayoutMode.speaker);
    });
  });

  group('moderation', () {
    test('mutes a participant in the chat the call is in', () async {
      tokenAnswers();
      when(
        () => repository.muteCallParticipant(any(), any(), any()),
      ).thenAnswer((_) async => const Right(null));
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      final failure = await container
          .read(callProvider.notifier)
          .muteParticipant(42);

      expect(failure, isNull);
      verify(() => repository.muteCallParticipant(chatId, 42, true)).called(1);
    });

    test('refuses when there is no call to moderate', () async {
      final container = boot();

      final failure = await container
          .read(callProvider.notifier)
          .muteParticipant(42);

      expect(failure, isA<InputFailure>());
      verifyNever(() => repository.muteCallParticipant(any(), any(), any()));
    });

    test('a refused mute surfaces on the call state', () async {
      tokenAnswers();
      when(
        () => repository.muteCallParticipant(any(), any(), any()),
      ).thenAnswer(
        (_) async => const Left(
          ApiFailure(
            code: 'ACCESS_DENIED',
            message: 'nope',
            detail: null,
            status: 403,
          ),
        ),
      );
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      final failure = await container
          .read(callProvider.notifier)
          .muteParticipant(42, muted: false);

      expect(failure, isA<ApiFailure>());
      expect(container.read(callProvider).failure, failure);
      verify(() => repository.muteCallParticipant(chatId, 42, false)).called(1);
    });
  });

  group('mini player visibility', () {
    test('shows only while a call is live and its screen is not', () async {
      tokenAnswers();
      final container = boot();

      expect(container.read(callMiniPlayerVisibleProvider), isFalse);

      await container.read(callProvider.notifier).join(chatId);
      expect(container.read(callMiniPlayerVisibleProvider), isTrue);

      container.read(callScreenVisibleProvider.notifier).set(visible: true);
      expect(container.read(callMiniPlayerVisibleProvider), isFalse);

      container.read(callScreenVisibleProvider.notifier).set(visible: false);
      expect(container.read(callMiniPlayerVisibleProvider), isTrue);

      await container.read(callProvider.notifier).leave();
      expect(container.read(callMiniPlayerVisibleProvider), isFalse);
    });

    test('stays up while the call is reconnecting', () async {
      tokenAnswers();
      final container = boot();
      await container.read(callProvider.notifier).join(chatId);

      service.emit(CallRoomSignal.reconnecting);
      await pumpEventQueue();

      expect(container.read(callMiniPlayerVisibleProvider), isTrue);
    });
  });
}
