import 'package:flutter/material.dart';

abstract final class ChatixPalette {
  static const Color violet = Color(0xFF6E56F8);

  static const Color indigo = Color(0xFF4B36C9);

  static const Color mint = Color(0xFF22C7A9);

  static const Color coral = Color(0xFFF2624F);

  static const Color amber = Color(0xFFF5A524);

  static const Color graphite900 = Color(0xFF14120F);
  static const Color graphite800 = Color(0xFF1D1A16);
  static const Color graphite700 = Color(0xFF2A2520);
  static const Color graphite600 = Color(0xFF3D362E);
  static const Color graphite400 = Color(0xFF7A7168);
  static const Color graphite200 = Color(0xFFD9D2C9);
  static const Color graphite100 = Color(0xFFEDE8E1);
  static const Color graphite50 = Color(0xFFF8F5F1);

  static const List<({Color light, Color dark})> authorAccents = [
    (light: Color(0xFF6E56F8), dark: Color(0xFFB0A1FF)), // violet
    (light: Color(0xFF0E9F86), dark: Color(0xFF5FE0C6)), // mint
    (light: Color(0xFFD1442F), dark: Color(0xFFFF9382)), // coral
    (light: Color(0xFFB07400), dark: Color(0xFFF5C46A)), // amber
    (light: Color(0xFF2563C9), dark: Color(0xFF8FBAFF)), // azure
    (light: Color(0xFFB13FA8), dark: Color(0xFFF19CE9)), // orchid
    (light: Color(0xFF4C7A21), dark: Color(0xFFAEDC77)), // moss
    (light: Color(0xFF9B5524), dark: Color(0xFFF0AC7B)), // clay
  ];

  static Color authorColor(int? userId, Brightness brightness) {
    if (userId == null) return graphite400;
    final entry = authorAccents[userId.abs() % authorAccents.length];
    return brightness == Brightness.dark ? entry.dark : entry.light;
  }
}
