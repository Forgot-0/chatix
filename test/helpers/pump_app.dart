import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/core/providers/storage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'fakes/fake_secure_storage_service.dart';

/// Default overrides every widget/golden test should start from.
///
/// The project's DI graph is built the same way in tests as in [main] —
/// via `ProviderScope(overrides: [...])` — so the correct place to keep a
/// screen from touching a real platform channel is at the same seam
/// `main()` already uses for its own required overrides
/// (`sharedPreferencesProvider`, `cookieJarProvider`): override the
/// interface, not the widget or the notifier built on top of it. That way
/// tests still exercise real business logic (e.g. the real
/// `AuthController`), just against a fake at the infrastructure boundary.
///
/// Add to this list as new platform-touching providers end up reachable
/// from a screen's `build()` (i.e. eagerly, not just from a button-press
/// handler) — `sharedPreferencesProvider`/`cookieJarProvider` aren't here
/// yet because nothing in the auth feature reads them during `build()`;
/// if that changes, give them the same interface+fake treatment as
/// [SecureStorageService] and add the override here.
List<Override> defaultTestOverrides({
  Map<String, String>? secureStorageValues,
}) {
  return [
    secureStorageServiceProvider.overrideWithValue(
      FakeSecureStorageService(initialValues: secureStorageValues),
    ),
  ];
}

/// Wraps [child] in a [ProviderScope] pre-loaded with
/// [defaultTestOverrides]. Pass [secureStorageValues] with an
/// `AppConstants.accessTokenKey` entry to test the "already logged in"
/// path; leave it null for the default logged-out state. [overrides]
/// are appended after the defaults, so a test can still swap in a
/// different fake (or the real thing) for a specific provider if needed.
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
