import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatix/features/project/domain/entities/project_member_entity.dart';
import 'package:chatix/features/project/domain/entities/project_role_entity.dart';
import 'package:chatix/features/project/presentation/providers/project_detail_provider.dart';
import 'package:chatix/features/project/presentation/providers/project_providers.dart';
import 'package:chatix/features/project/presentation/utils/project_permissions.dart';
import 'package:chatix/features/project/presentation/widgets/project_common.dart';

/// One member row. When [canManage] is true (current user has `member:udpate`)
/// a trailing menu exposes "Change role" and "Edit permissions", wired to
/// `changeMemberRole` / `updateMemberPermissions` and invalidating the project
/// detail afterwards so the tab reflects the new state.
class MemberListTile extends ConsumerWidget {
  const MemberListTile({
    super.key,
    required this.projectId,
    required this.member,
    required this.canManage,
  });

  final int projectId;
  final ProjectMemberEntity member;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(child: Text('#${member.userId}')),
      title: Text('User #${member.userId}'),
      subtitle: Text(
        '${member.role?.name ?? 'no role'} · ${memberStatusLabel(member.status)}',
      ),
      trailing: canManage
          ? PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'role') {
                  showChangeRoleDialog(context, ref, projectId, member);
                } else if (value == 'perms') {
                  showEditPermissionsDialog(context, ref, projectId, member);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'role', child: Text('Change role')),
                PopupMenuItem(value: 'perms', child: Text('Edit permissions')),
              ],
            )
          : null,
    );
  }
}

/// `POST /projects/{id}/invite/` — pick a user id + role (roles come from the
/// public `GET /project_roles/`). [roleId] is required (api-docs §9.2).
Future<void> showInviteMemberDialog(BuildContext context, WidgetRef ref, int projectId) async {
  final userIdController = TextEditingController();
  int? selectedRoleId;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, dialogRef, _) {
          final rolesAsync = dialogRef.watch(projectRolesProvider);
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Invite member'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: userIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'User id'),
                    ),
                    const SizedBox(height: 12),
                    rolesAsync.when(
                      loading: () => const CircularProgressIndicator(),
                      error: (_, __) => const Text('Failed to load roles'),
                      data: (roles) => DropdownButtonFormField<int>(
                        initialValue: selectedRoleId,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: roles
                            .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                            .toList(),
                        onChanged: (v) => setState(() => selectedRoleId = v),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final userId = int.tryParse(userIdController.text.trim());
                      if (userId == null || selectedRoleId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter a user id and pick a role')),
                        );
                        return;
                      }
                      final result = await ref.read(inviteMemberUseCaseProvider).execute(
                            projectId,
                            userId: userId,
                            roleId: selectedRoleId!,
                          );
                      if (!dialogContext.mounted) return;
                      result.fold(
                        (f) => ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(SnackBar(content: Text(f.message))),
                        (_) {
                          ref.invalidate(projectDetailProvider(projectId));
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Invite sent')));
                        },
                      );
                    },
                    child: const Text('Invite'),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

/// `POST /projects/{id}/members/{userId}/role/`.
Future<void> showChangeRoleDialog(
  BuildContext context,
  WidgetRef ref,
  int projectId,
  ProjectMemberEntity member,
) async {
  int? selectedRoleId = member.roleId;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, dialogRef, _) {
          final rolesAsync = dialogRef.watch(projectRolesProvider);
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text('Change role · User #${member.userId}'),
                content: rolesAsync.when(
                  loading: () => const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, __) => const Text('Failed to load roles'),
                  data: (roles) => DropdownButtonFormField<int>(
                    initialValue: selectedRoleId,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: roles
                        .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedRoleId = v),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      if (selectedRoleId == null) return;
                      final result = await ref.read(changeMemberRoleUseCaseProvider).execute(
                            projectId,
                            userId: member.userId,
                            roleId: selectedRoleId!,
                          );
                      if (!dialogContext.mounted) return;
                      result.fold(
                        (f) => ScaffoldMessenger.of(dialogContext)
                            .showSnackBar(SnackBar(content: Text(f.message))),
                        (_) {
                          ref.invalidate(projectDetailProvider(projectId));
                          Navigator.pop(dialogContext);
                        },
                      );
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          );
        },
      );
    },
  );
}

/// `PUT /projects/{id}/members/{userId}/permissions/` — toggle the full set of
/// project permission keys (api-docs §9.2). Each switch is seeded from the
/// member's effective value (override if set, else the role's grant).
Future<void> showEditPermissionsDialog(
  BuildContext context,
  WidgetRef ref,
  int projectId,
  ProjectMemberEntity member,
) async {
  const allKeys = <String>[
    ProjectPermissions.memberRead,
    ProjectPermissions.memberInvite,
    ProjectPermissions.memberKick,
    ProjectPermissions.memberUpdate,
    ProjectPermissions.projectRead,
    ProjectPermissions.projectUpdate,
    ProjectPermissions.projectVisibility,
    ProjectPermissions.projectDelete,
    ProjectPermissions.positionCreate,
    ProjectPermissions.positionUpdate,
    ProjectPermissions.positionDelete,
    ProjectPermissions.permissionUpdate,
  ];

  final ProjectRoleEntity? role = member.role;
  final overrides = <String, bool>{
    for (final k in allKeys)
      k: member.permissionsOverrides[k] ?? (role?.permissions[k] ?? false),
  };

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Permissions · User #${member.userId}'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: allKeys
                    .map((k) => SwitchListTile(
                          dense: true,
                          title: Text(k),
                          value: overrides[k] ?? false,
                          onChanged: (v) => setState(() => overrides[k] = v),
                        ))
                    .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final result = await ref
                      .read(updateMemberPermissionsUseCaseProvider)
                      .execute(
                        projectId,
                        userId: member.userId,
                        permissionsOverrides: overrides,
                      );
                  if (!dialogContext.mounted) return;
                  result.fold(
                    (f) => ScaffoldMessenger.of(dialogContext)
                        .showSnackBar(SnackBar(content: Text(f.message))),
                    (_) {
                      ref.invalidate(projectDetailProvider(projectId));
                      Navigator.pop(dialogContext);
                    },
                  );
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );
}
