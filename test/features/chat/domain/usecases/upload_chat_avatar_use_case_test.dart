import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:mocktail/mocktail.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/domain/entities/chat_avatar.dart';
import 'package:chatix/features/chat/domain/repositories/chat_avatar_repository.dart';
import 'package:chatix/features/chat/domain/usecases/upload_chat_avatar_use_case.dart';

class _MockRepository extends Mock implements ChatAvatarRepository {}

/// A group's picture: slot, PUT, confirm (api-docs §5.10) — and nothing
/// sent that the server would refuse on sight.
void main() {
  late _MockRepository repository;
  late UploadChatAvatarUseCase useCase;

  const slot = ChatAvatarUploadSlot(
    uploadToken: 'token-1',
    uploadUrl: 'https://storage.example.com/put?sig=1',
    expiresIn: 600,
  );
  final bytes = Uint8List.fromList(List<int>.filled(1024, 7));

  setUpAll(() {
    registerFallbackValue(slot);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repository = _MockRepository();
    useCase = UploadChatAvatarUseCase(repository);

    when(
      () => repository.requestUpload(
        any(),
        mimeType: any(named: 'mimeType'),
        fileSize: any(named: 'fileSize'),
      ),
    ).thenAnswer((_) async => const Right(slot));
    when(
      () => repository.upload(
        any(),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) async => const Right(null));
    when(
      () => repository.confirmUpload(
        any(),
        uploadToken: any(named: 'uploadToken'),
      ),
    ).thenAnswer((_) async => const Right(null));
  });

  test('asks for a slot with the real type and size, PUTs, confirms', () async {
    final result = await useCase.execute(
      'c1',
      bytes: bytes,
      mimeType: 'image/png',
    );

    expect(result.isRight(), isTrue);
    verifyInOrder([
      () =>
          repository.requestUpload('c1', mimeType: 'image/png', fileSize: 1024),
      () => repository.upload(slot, bytes: bytes, mimeType: 'image/png'),
      () => repository.confirmUpload('c1', uploadToken: 'token-1'),
    ]);
  });

  test('a type the server does not take is refused before a request', () async {
    final result = await useCase.execute(
      'c1',
      bytes: bytes,
      mimeType: 'image/heic',
    );

    expect(result.getLeft().toNullable(), isA<InputFailure>());
    verifyNever(
      () => repository.requestUpload(
        any(),
        mimeType: any(named: 'mimeType'),
        fileSize: any(named: 'fileSize'),
      ),
    );
  });

  test('over 5 MB is refused before a request', () async {
    final result = await useCase.execute(
      'c1',
      bytes: Uint8List(ChatAvatarLimits.maxBytes + 1),
      mimeType: 'image/jpeg',
    );

    expect(result.getLeft().toNullable(), isA<InputFailure>());
    verifyNever(
      () => repository.requestUpload(
        any(),
        mimeType: any(named: 'mimeType'),
        fileSize: any(named: 'fileSize'),
      ),
    );
  });

  test('a PUT that fails is not confirmed', () async {
    when(
      () => repository.upload(
        any(),
        bytes: any(named: 'bytes'),
        mimeType: any(named: 'mimeType'),
      ),
    ).thenAnswer((_) async => const Left(NetworkFailure()));

    final result = await useCase.execute(
      'c1',
      bytes: bytes,
      mimeType: 'image/webp',
    );

    expect(result.getLeft().toNullable(), isA<NetworkFailure>());
    verifyNever(
      () => repository.confirmUpload(
        any(),
        uploadToken: any(named: 'uploadToken'),
      ),
    );
  });

  test("the server's refusal of the slot is handed back as is", () async {
    const refusal = ApiFailure(
      code: 'CHAT_AVATAR_VALIDATION',
      message: 'bad',
      detail: {'reason': 'direct_chat'},
      status: 400,
    );
    when(
      () => repository.requestUpload(
        any(),
        mimeType: any(named: 'mimeType'),
        fileSize: any(named: 'fileSize'),
      ),
    ).thenAnswer((_) async => const Left(refusal));

    final result = await useCase.execute(
      'c1',
      bytes: bytes,
      mimeType: 'image/jpeg',
    );

    expect(result.getLeft().toNullable(), refusal);
  });
}
