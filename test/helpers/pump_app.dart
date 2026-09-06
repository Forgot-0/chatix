import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'fakes/fake_secure_storage_service.dart';

List<Override> defaultTestOverrides({
  Map<String, String>? secureStorageValues,
}) {
  return [
    secureStorageServiceProvider.overrideWithValue(
      FakeSecureStorageService(initialValues: secureStorageValues),
    ),
  ];
}

Widget pumpableApp({
  required Widget child,
  List<Override> overrides = const [],
  Map<String, String>? secureStorageValues,
}) {
  return ProviderScope(
    overrides: [
      ...defaultTestOverrides(secureStorageValues: secureStorageValues),
      ...overrides,
    ],
    child: child,
  );
}
