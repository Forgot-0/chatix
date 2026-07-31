import 'package:chatix/features/project/domain/entities/project_member_entity.dart';

/// Canonical project-permission keys (api-docs §9.2). Use these constants
/// everywhere instead of hand-typing the strings — one typo in a literal
/// silently disables a button.
///
/// ⚠️ [memberUpdate] maps to the string `"member:udpate"` — the misspelling
/// (`udpate`, no second "a") is baked into the backend seed data and must be
/// sent/compared verbatim, even though our Dart symbol is spelled correctly.
abstract final class ProjectPermissions {
  static const String memberRead = 'member:read';
  static const String memberInvite = 'member:invite';
  static const String memberKick = 'member:kick';

  /// ⚠️ Intentional backend typo — see class doc.
  static const String memberUpdate = 'member:udpate';

  static const String projectRead = 'project:read';
  static const String projectUpdate = 'project:update';
  static const String projectVisibility = 'project:visibility';
  static const String projectDelete = 'project:delete';

  static const String positionCreate = 'position:create';
  static const String positionUpdate = 'position:update';
  static const String positionDelete = 'position:delete';

  static const String permissionUpdate = 'permission:update';
}

/// Whether the current member ([me]) is granted [permission] on the project.
///
/// Resolution order (api-docs §5.2, §10.6):
///   1. `me.permissionsOverrides[permission]` if that key is present — a
///      per-member override wins over the role default (either direction).
///   2. otherwise `me.role.permissions[permission] == true`.
///   3. otherwise `false` (fail-closed).
///
/// [me] is nullable on purpose: for a viewer who isn't a member of the
/// project (e.g. browsing a public project) there's no membership, so every
/// management permission is denied and the corresponding buttons stay hidden.
///
/// This is the single source of truth the presentation layer should call to
/// decide whether to *show* a management control. The server still enforces
/// the real check — hiding a button is a UX affordance, not security.
bool hasProjectPermission(ProjectMemberEntity? me, String permission) {
  if (me == null) return false;

  final override = me.permissionsOverrides[permission];
  if (override != null) return override;

  final role = me.role;
  if (role == null) return false;
  return role.permissions[permission] == true;
}
