import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chatix/core/utils/app_utils.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';
import 'package:chatix/features/profile/domain/entities/contact_entity.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_picker_widget.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/error/failure_messages.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final int? profileId;

  const ProfileScreen({super.key, this.profileId});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isStartingChat = false;

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authProvider).value?.id;
    final resolvedProfileId = widget.profileId ?? currentUserId;

    if (resolvedProfileId == null) {
      return Scaffold(
        body: Center(
          child: Text(AppLocalizations.of(context).signInToViewProfile),
        ),
      );
    }

    final canEdit = resolvedProfileId == currentUserId;
    final profileAsync = ref.watch(profileDetailProvider(resolvedProfileId));

    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        actions: [
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => context.push(ProfileEditRoute.location),
            ),
            IconButton(
              tooltip: l10n.browsePeople,
              icon: const Icon(Icons.people_outline),
              onPressed: () => context.push(ProfilesRoute.location),
            ),
            IconButton(
              tooltip: l10n.settings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(SettingsRoute.location),
            ),
          ],
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ProfileError(
          message: friendlyFailureMessage(
            error,
            fallback: AppLocalizations.of(context).profileLoadFailed,
          ),
          onRetry: () =>
              ref.invalidate(profileDetailProvider(resolvedProfileId)),
        ),
        data: (profile) => RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(profileDetailProvider(resolvedProfileId)),
          child: _ProfileContent(profile: profile, canEdit: canEdit),
        ),
      ),
      floatingActionButton: canEdit || currentUserId == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _isStartingChat
                  ? null
                  : () => _startDirectChat(resolvedProfileId),
              icon: _isStartingChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: Text(l10n.sendMessageAction),
            ),
    );
  }

  Future<void> _startDirectChat(int userId) async {
    setState(() => _isStartingChat = true);

    final result = await ref
        .read(createChatUseCaseProvider)
        .execute(chatType: ChatType.direct, memberIds: [userId]);

    if (!mounted) return;
    setState(() => _isStartingChat = false);

    result.match(
      (failure) {
        final existingChatId = existingDirectChatId(failure);
        if (existingChatId != null) {
          ref.read(chatListProvider.notifier).refresh();
          context.push(ChatDetailRoute(existingChatId).location);
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chatFailureMessage(failure) ??
                  friendlyFailureMessage(
                    failure,
                    fallback: AppLocalizations.of(context).startChatFailed,
                  ),
            ),
          ),
        );
      },
      (chat) {
        ref.read(chatListProvider.notifier).refresh();
        context.push(ChatDetailRoute(chat.id).location);
      },
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
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
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
          Text(
            AppLocalizations.of(context).profileAbout,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(profile.bio!),
        ],
        if (profile.skills.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).profileSkills,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: profile.skills
                .map((skill) => Chip(label: Text(skill)))
                .toList(),
          ),
        ],
        if (profile.contacts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context).profileContacts,
            style: theme.textTheme.titleMedium,
          ),
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
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
