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
        widget: pumpableApp(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
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
