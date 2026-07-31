import 'package:equatable/equatable.dart';

/// `ProjectRoleDTO` (api-docs §5.5). Roles are **read-only** over REST —
/// there is no POST/PUT for `/project_roles/` at all (api-docs §5.5, this
/// is intentional on the backend, not a missing feature).
///
/// The seeded roles are `owner (id=1)`, `maintainer (id=2)`,
/// `developer (id=4)`, `user (id=5)` — note `id=3` does not exist
/// (api-docs §9.2), so never assume the ids are contiguous.
class ProjectRoleEntity extends Equatable {
  final int id;
  final String name;

  /// The full permission matrix for this role, keyed by permission string
  /// (e.g. `project:update`, `member:invite`). See [ProjectPermissions] for
  /// the canonical key list and api-docs §9.2 for the per-role matrix.
  ///
  /// ⚠️ One of the keys is literally spelled `member:udpate` (typo baked
  /// into the backend seed data, api-docs §9.2) — we keep our Dart symbol
  /// readable ([ProjectPermissions.memberUpdate]) but the *string* sent to
  /// and compared against the server must stay `member:udpate` verbatim.
  final Map<String, bool> permissions;

  const ProjectRoleEntity({
    required this.id,
    required this.name,
    required this.permissions,
  });

  /// `true` only when [permission] is present **and** `true`. A missing key
  /// is treated as "not granted" (fail-closed), which matches how the
  /// backend evaluates an absent permission.
  bool grants(String permission) => permissions[permission] == true;

  @override
  List<Object?> get props => [id, name, permissions];
}
