import 'package:flutter/material.dart';

abstract class FeatureFlagService {
  Future<void> init();

  bool isFeatureEnabled(String featureKey);

  String getString(String key, {required String defaultValue});

  int getInt(String key, {required int defaultValue});

  double getDouble(String key, {required double defaultValue});

  bool getBool(String key, {required bool defaultValue});

  Color getColor(String key, {required Color defaultValue});

  Future<void> fetchAndActivate();

  void setDefaults(Map<String, dynamic> defaults);

  void addListener(VoidCallback listener);

  void removeListener(VoidCallback listener);

  void dispose();
}
