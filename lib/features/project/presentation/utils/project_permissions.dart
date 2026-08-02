/// Project permission helpers — **moved** to
/// `core/rbac/permission_helpers.dart`.
///
/// See that file for the reasoning (one implementation of the api-docs §9.2
/// matrix, reusable from app-bar actions and from other features). This file
/// remains as a re-export so existing imports keep working; new code should
/// import `package:chatix/core/rbac/permission_helpers.dart` directly.
library;

export 'package:chatix/core/rbac/permission_helpers.dart'
    show
        ProjectPermissions,
        hasAnyProjectManagementPermission,
        hasProjectPermission;
