import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

const Map<String, bool> chatGoldenThemes = <String, bool>{
  'light': false,
  'dark': true,
};

ThemeData chatGoldenTheme({required bool dark}) =>
    dark ? AppTheme.darkTheme : AppTheme.lightTheme;

Future<void> pumpChatGolden(
  WidgetTester tester, {
  required Widget child,
  required String name,
  required bool dark,
  Size surfaceSize = const Size(320, 120),
  CustomPump? pump,
  Future<void> Function(WidgetTester tester)? interact,
}) async {
  final theme = chatGoldenTheme(dark: dark);

  await tester.pumpWidgetBuilder(
    ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      ),
    ),
    wrapper: materialAppWrapper(
      theme: theme,
      localizations: AppLocalizations.localizationsDelegates,
    ),
    surfaceSize: surfaceSize,
  );

  await interact?.call(tester);

  await screenMatchesGolden(tester, name, customPump: pump);
}

final Uint8List kStubImageBytes = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x08,
  0x00,
  0x00,
  0x00,
  0x08,
  0x08,
  0x02,
  0x00,
  0x00,
  0x00,
  0x4B,
  0x6D,
  0x29,
  0xDC,
  0x00,
  0x00,
  0x00,
  0x24,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0xDA,
  0x63,
  0xE0,
  0x2E,
  0x6A,
  0x05,
  0xA2,
  0xAF,
  0x4B,
  0x55,
  0x80,
  0x08,
  0x99,
  0xCD,
  0x80,
  0x55,
  0x14,
  0xC8,
  0x60,
  0xC0,
  0x2A,
  0x0A,
  0x95,
  0xC0,
  0x6A,
  0x1A,
  0x03,
  0x1D,
  0xEC,
  0x00,
  0x00,
  0x6D,
  0xA6,
  0x58,
  0x01,
  0xF5,
  0x10,
  0x92,
  0xFD,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);
