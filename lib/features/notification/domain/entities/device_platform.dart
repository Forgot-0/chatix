import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

enum DevicePlatform {
  ios('IOS'),
  web('WEB'),
  android('ANDROID');

  const DevicePlatform(this.wire);

  final String wire;

  static DevicePlatform? get current {
    if (kIsWeb) return DevicePlatform.web;
    if (Platform.isIOS) return DevicePlatform.ios;
    if (Platform.isAndroid) return DevicePlatform.android;
    return null;
  }
}
