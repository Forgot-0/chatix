import 'package:equatable/equatable.dart';

/// One signed-in device, as reported by `GET /users/sessions/`.
class SessionEntity extends Equatable {
  const SessionEntity({
    required this.id,
    required this.userId,
    required this.deviceInfo,
    required this.userAgent,
    required this.lastActivity,
    required this.isActive,
  });

  final int id;
  final int userId;
  final String deviceInfo;
  final String userAgent;
  final DateTime? lastActivity;
  final bool isActive;

  /// `device_info` is free-form and often empty; fall back to the user agent
  /// rather than showing a blank row.
  String get label {
    final info = deviceInfo.trim();
    if (info.isNotEmpty) return info;
    final agent = userAgent.trim();
    if (agent.isNotEmpty) return agent;
    return 'Session #$id';
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    deviceInfo,
    userAgent,
    lastActivity,
    isActive,
  ];
}
