import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:chatix/core/theme/app_theme.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  testGoldens('LoginScreen golden test', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(
        devices: [Device.phone, Device.iphone11, Device.tabletPortrait],
      )
      ..addScenario(
        widget: pumpableApp(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            // The real app theme and ARB delegates: the screen reads both, so
            // a golden built on stand-ins would not be the shipped screen.
            theme: AppTheme.lightTheme,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
        name: 'default_login_state',
      );

    await tester.pumpDeviceBuilder(builder);

    await screenMatchesGolden(tester, 'login_screen');
  });
}
