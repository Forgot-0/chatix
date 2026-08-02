/// Chat permission helpers — **moved** to `core/rbac/permission_helpers.dart`.
///
/// The implementation now lives in `core/` because the same questions
/// ("may I delete this chat?", "may I invite here?") are asked from app-bar
/// actions and overflow menus that belong to no single feature, and from the
/// project feature's screens. Two copies of a §9.1 rule drift, and the
/// symptom is a button that 403s.
///
/// This file stays as a re-export so the existing
/// `features/chat/.../chat_permissions.dart` imports (and their tests) keep
/// compiling and keep pointing at exactly one implementation. New code should
/// import `package:chatix/core/rbac/permission_helpers.dart` directly.
library;

export 'package:chatix/core/rbac/permission_helpers.dart'
    show
        ChatPermissions,
        canDeleteMessage,
        canEditMessage,
        canLeaveChat,
        canModerate,
        canSendMessage,
        hasAnyChatManagementAction,
        hasChatPermission;
