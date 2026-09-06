import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/profile/data/models/avatar_presign_model.dart';

void main() {
  const wireBody =
      '{"url":"https://storage.windoweropu.store/pending-avatar/1/'
      '%D0%A1%D0%BD%D0%B8%D0%BC%D0%BE%D0%BA_%D1%8D%D0%BA%D1%80%D0%B0%D0%BD'
      '%D0%B0_%D0%BE%D1%82_2026-09-04_23-50-28.png'
      '?X-Amz-Algorithm=AWS4-HMAC-SHA256'
      '&X-Amz-Credential=minio%2F20260904%2Fus-east-1%2Fs3%2Faws4_request'
      '&X-Amz-Date=20260904T220605Z&X-Amz-Expires=90&X-Amz-SignedHeaders=host'
      '&X-Amz-Signature=6b7c201ce0762af74e1b4f334a91c138db394a4f596'
      '15f535e23629efca38c56",'
      '"file_key":"1/Снимок_экрана_от_2026-09-04_23-50-28.png"}';

  test('parses the real presign response', () {
    final json = jsonDecode(wireBody) as Map<String, dynamic>;

    final model = AvatarPresignModel.fromJson(json);

    expect(model.url, startsWith('https://storage.windoweropu.store/'));
    expect(model.fileKey, '1/Снимок_экрана_от_2026-09-04_23-50-28.png');
  });

  test('the signature stays in the URL — there are no policy fields', () {
    final model = AvatarPresignModel.fromJson(
      jsonDecode(wireBody) as Map<String, dynamic>,
    );

    expect(model.url, contains('X-Amz-Signature='));
    expect(model.url, contains('X-Amz-Expires=90'));
  });

  test('file_key is the server-sanitised name, not the one we sent', () {
    final model = AvatarPresignModel.fromJson(
      jsonDecode(wireBody) as Map<String, dynamic>,
    );

    expect(model.fileKey, isNot(contains(' ')));
    expect(model.fileKey, startsWith('1/'));
  });

  test('toEntity carries both fields through unchanged', () {
    final entity = AvatarPresignModel.fromJson(
      jsonDecode(wireBody) as Map<String, dynamic>,
    ).toEntity();

    expect(entity.fileKey, '1/Снимок_экрана_от_2026-09-04_23-50-28.png');
    expect(entity.url, contains('X-Amz-Signature='));
  });
}
