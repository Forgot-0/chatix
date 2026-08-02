import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_picker_widget.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/error/failure_messages.dart';

/// Views a profile — the signed-in person's own when [profileId] is `null`,
/// otherwise whichever profile [profileId] points to. The "Edit" entry
/// point (app bar action + avatar upload control) only ever shows for the
/// caller's own profile: there's no system-rights UI yet, so ownership is
/// the only condition checked here (api-docs §4.4/§4.6).
class ProfileScreen extends ConsumerWidget {
  final int? profileId;

  const ProfileScreen({super.key, this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(authProvider).value?.id;
    final resolvedProfileId = profileId ?? currentUserId;

    if (resolvedProfileId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to view your profile')));
    }

    final canEdit = resolvedProfileId == currentUserId;
    final profileAsync = ref.watch(profileDetailProvider(resolvedProfileId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push(ProfileEditRoute.location),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileError(
          message: friendlyFailureMessage(error, fallback: 'Could not load this profile'),
          onRetry: () => ref.invalidate(profileDetailProvider(resolvedProfileId)),
        ),
        data: (profile) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(profileDetailProvider(resolvedProfileId)),
          child: _ProfileContent(profile: profile, canEdit: canEdit),
        ),
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final ProfileEntity profile;
  final bool canEdit;

  const _ProfileContent({required this.profile, required this.canEdit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: canEdit
              ? AvatarPickerWidget(profile: profile)
              : ProfileAvatar(profile: profile, radius: 48),
        ),
        const SizedBox(height: 16),
        if (profile.displayName != null)
          Center(
            child: Text(
              profile.displayName!,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
        if (profile.specialization != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                profile.specialization!,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.secondary),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        if (profile.dateBirthday != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                AppUtils.formatDate(profile.dateBirthday!),
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        if (profile.bio != null && profile.bio!.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(profile.bio!),
        ],
        if (profile.skills.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Skills', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.skills.map((skill) => Chip(label: Text(skill))).toList(),
          ),
        ],
        if (profile.contacts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Contacts', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...profile.contacts.map((contact) => _ContactTile(contact: contact)),
        ],
      ],
    );
  }
}

class _ContactTile extends StatelessWidget {
  final ContactEntity contact;

  const _ContactTile({required this.contact});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.link),
      title: Text(contact.contact),
      subtitle: Text(contact.provider),
    );
  }
}

class _ProfileError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ProfileError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
