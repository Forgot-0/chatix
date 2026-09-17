import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/notifications/notification_providers.dart';
import 'package:chatix/core/notifications/notification_service.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/notification/data/repositories/notification_repository_impl.dart';
import 'package:chatix/features/notification/domain/entities/device_platform.dart';
import 'package:chatix/features/notification/domain/repositories/notification_repository.dart';
import 'package:chatix/features/notification/presentation/providers/push_providers.dart';

class _MockRepository extends Mock implements NotificationRepository {}

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);

  final UserEntity? _user;

  @override
  Future<UserEntity?> build() async => _user;
}

/// A notification service with nothing behind it but the two things push
/// registration actually reads: the current token and the stream the platform
/// rotates it on.
class _FakeService implements NotificationService {
  String? token = 'token-1';

  NotificationPermissionStatus status =
      NotificationPermissionStatus.authorized;

  final StreamController<String> tokens = StreamController<String>.broadcast();

  int permissionRequests = 0;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get tokenRefreshStream => tokens.stream;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    permissionRequests++;
    return status = NotificationPermissionStatus.authorized;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const me = UserEntity(id: 7, username: 'me', email: 'me@example.com');

  late _MockRepository repository;
  late _FakeService service;

  setUp(() {
    repository = _MockRepository();
    service = _FakeService();
    addTearDown(service.tokens.close);

    when(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: any(named: 'token'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) async => const Right(null));
  });

  ProviderContainer boot({UserEntity? user = me}) {
    final container = ProviderContainer(
      overrides: [
        authProvider.overrideWith(() => _FakeAuthController(user)),
        notificationServiceProvider.overrideWithValue(service),
        notificationRepositoryProvider.overrideWithValue(repository),
        // The test host is neither of the three platforms the API knows.
        devicePlatformProvider.overrideWithValue(DevicePlatform.android),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('registers the current token once signed in', () async {
    final container = boot();
    container.listen(pushRegistrationProvider, (_, _) {});

    await pumpEventQueue();

    verify(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: 'token-1',
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);
    expect(container.read(pushRegistrationProvider), 'token-1');
  });

  test('registers again when the platform rotates the token', () async {
    final container = boot();
    container.listen(pushRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    service.tokens.add('token-2');
    await pumpEventQueue();

    verify(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: 'token-2',
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);
    expect(container.read(pushRegistrationProvider), 'token-2');
  });

  test('does not re-post a token the server already has', () async {
    final container = boot();
    container.listen(pushRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    service.tokens.add('token-1');
    await pumpEventQueue();

    verify(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: any(named: 'token'),
        deviceName: any(named: 'deviceName'),
      ),
    ).called(1);
  });

  test('asks for the grant the first time and never after a refusal', () async {
    service.status = NotificationPermissionStatus.denied;

    final container = boot();
    container.listen(pushRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    expect(service.permissionRequests, 0);
    verifyNever(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: any(named: 'token'),
        deviceName: any(named: 'deviceName'),
      ),
    );
  });

  test('a signed-out app registers nothing', () async {
    final container = boot(user: null);
    container.listen(pushRegistrationProvider, (_, _) {});

    await pumpEventQueue();

    verifyNever(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: any(named: 'token'),
        deviceName: any(named: 'deviceName'),
      ),
    );
    expect(container.read(pushRegistrationProvider), isNull);
  });

  test('a build without a push token registers nothing', () async {
    service.token = null;

    final container = boot();
    container.listen(pushRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    verifyNever(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: any(named: 'token'),
        deviceName: any(named: 'deviceName'),
      ),
    );
  });

  test('a server that refuses the device leaves nothing registered', () async {
    when(
      () => repository.registerDevice(
        platform: any(named: 'platform'),
        token: any(named: 'token'),
        deviceName: any(named: 'deviceName'),
      ),
    ).thenAnswer((_) async => const Left(ServerFailure(message: 'nope')));

    final container = boot();
    container.listen(pushRegistrationProvider, (_, _) {});
    await pumpEventQueue();

    expect(container.read(pushRegistrationProvider), isNull);
  });
}
