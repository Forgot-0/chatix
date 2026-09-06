import 'package:equatable/equatable.dart';

class ChatProfileEntity extends Equatable {
  final int userId;

  final String? username;

  final String? displayName;

  final String? avatarUrl;

  final String? avatarS3Key;

  const ChatProfileEntity({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.avatarS3Key,
  });

  String get bestName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    return 'User #$userId';
  }

  @override
  List<Object?> get props => [
    userId,
    username,
    displayName,
    avatarUrl,
    avatarS3Key,
  ];
}

String chatDisplayName(ChatProfileEntity? profile, int? userId) {
  if (profile != null) return profile.bestName;
  if (userId != null) return 'User #$userId';
  return 'unknown';
}
