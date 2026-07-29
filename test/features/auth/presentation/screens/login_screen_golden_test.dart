import 'package:flutter/material.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:chatix/features/auth/presentation/screens/login_screen.dart';
import '../../../../helpers/pump_app.dart';

void main() {
  testGoldens('LoginScreen golden test', (tester) async {
    final builder = DeviceBuilder()
      ..overrideDevicesForAllScenarios(
        devices: [Device.phone, Device.iphone11, Device.tabletPortrait],
      )
      ..addScenario(
        // No secure-storage seed => no stored token => AuthController.build()
        // resolves straight to "logged out" without ever reaching the
        // network layer either. Real AuthController runs here, just against
        // the fake storage from test/helpers — see pump_app.dart for why.
        widget: pumpableApp(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            // Basic theme
            theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
            home: const LoginScreen(),
          ),
        ),
        name: 'default_login_state',
      );

    await tester.pumpDeviceBuilder(builder);

    await screenMatchesGolden(tester, 'login_screen');
  });
}
