import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/auth/domain/entities/session_entity.dart';
import 'package:chatix/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatix/features/auth/domain/usecases/get_my_sessions_use_case.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository repository;
  late GetMySessionsUseCase useCase;

  setUp(() {
    repository = MockAuthRepository();
    useCase = GetMySessionsUseCase(repository);
  });

  SessionEntity session({
    required int id,
    bool isActive = true,
    DateTime? lastActivity,
    String deviceInfo = '',
    String userAgent = '',
  }) => SessionEntity(
    id: id,
    userId: 7,
    deviceInfo: deviceInfo,
    userAgent: userAgent,
    lastActivity: lastActivity,
    isActive: isActive,
  );

  test('active sessions come before signed-out ones', () async {
    when(() => repository.getMySessions()).thenAnswer(
      (_) async => Right([
        session(id: 1, isActive: false, lastActivity: DateTime.utc(2026, 5)),
        session(id: 2, lastActivity: DateTime.utc(2026, 1)),
      ]),
    );

    final result = await useCase.execute();
    final ids = result.getRight().toNullable()!.map((s) => s.id);

    expect(ids, [2, 1]);
  });

  test('within a group, the most recently used comes first', () async {
    when(() => repository.getMySessions()).thenAnswer(
      (_) async => Right([
        session(id: 1, lastActivity: DateTime.utc(2026, 1)),
        session(id: 2, lastActivity: DateTime.utc(2026, 6)),
        session(id: 3, lastActivity: DateTime.utc(2026, 3)),
      ]),
    );

    final result = await useCase.execute();
    final ids = result.getRight().toNullable()!.map((s) => s.id);

    expect(ids, [2, 3, 1]);
  });

  test('a session with no timestamp sorts last rather than crashing', () async {
    when(() => repository.getMySessions()).thenAnswer(
      (_) async => Right([
        session(id: 1),
        session(id: 2, lastActivity: DateTime.utc(2026, 6)),
      ]),
    );

    final result = await useCase.execute();
    final ids = result.getRight().toNullable()!.map((s) => s.id);

    expect(ids, [2, 1]);
  });

  test('the repository list is not mutated in place', () async {
    final original = [
      session(id: 1, lastActivity: DateTime.utc(2026, 1)),
      session(id: 2, lastActivity: DateTime.utc(2026, 6)),
    ];
    when(
      () => repository.getMySessions(),
    ).thenAnswer((_) async => Right(original));

    await useCase.execute();

    expect(original.map((s) => s.id), [1, 2]);
  });

  test('surfaces the repository failure untouched', () async {
    const failure = ApiFailure(
      code: 'ACCESS_DENIED',
      message: 'nope',
      detail: <String, dynamic>{},
      status: 403,
    );
    when(
      () => repository.getMySessions(),
    ).thenAnswer((_) async => const Left(failure));

    expect(await useCase.execute(), const Left(failure));
  });

  group('SessionEntity.label', () {
    test('prefers device_info', () {
      expect(
        session(id: 1, deviceInfo: 'Pixel 8', userAgent: 'Dart/3.0').label,
        'Pixel 8',
      );
    });

    test('falls back to the user agent when device_info is blank', () {
      expect(
        session(id: 1, deviceInfo: '   ', userAgent: 'Dart/3.0').label,
        'Dart/3.0',
      );
    });

    test('degrades to the session id when the backend sent neither', () {
      expect(session(id: 9).label, 'Session #9');
    });
  });
}
