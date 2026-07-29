import 'package:equatable/equatable.dart';

/// Lightweight user, matching the `UserResponse` shape returned by
/// `/users/register/` and `/users/me/` (api-docs §3.2, §3.9).
///
/// There is no roles/permissions/sessions data here — the backend doesn't
/// expose a self-service endpoint for that (api-docs §3.9). A richer
/// `UserDetailEntity` (roles/permissions/sessions, `UserDTO` in api-docs
/// §3.11) is intentionally NOT modeled yet: it's only returned by the admin
/// `GET /users/` endpoint, which isn't used anywhere in the app yet. Add it
/// alongside the future admin/profile screens instead of speculatively now.
class UserEntity extends Equatable {
  final int id;
  final String username;
  final String email;

  const UserEntity({
    required this.id,
    required this.username,
    required this.email,
  });

  @override
  List<Object?> get props => [id, username, email];

  UserEntity copyWith({int? id, String? username, String? email}) {
    return UserEntity(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
    );
  }
}
