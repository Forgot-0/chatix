import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_quick_actions.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/direct_chat_opener.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/utils/profile_contact_link.dart';
import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_picker_widget.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_header.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about one person on one page.
///
/// The same screen serves "me" and "them": the difference is which actions
/// sit under the header and whether the account rows at the bottom are
/// there at all, not two near-identical layouts drifting apart.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.profileId});

  /// Null means the signed-in user's own profile.
  final int? profileId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// True while a direct chat is being found or created, so neither the
  /// message nor the call action can be asked for twice.
  bool _isOpeningChat = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final me = ref.watch(authProvider).value;
    final resolvedId = widget.profileId ?? me?.id;

    if (resolvedId == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        body: Center(child: Text(l10n.signInToViewProfile)),
      );
    }

    final isMe = resolvedId == me?.id;
    final profileAsync = ref.watch(profileDetailProvider(resolvedId));

    return profileAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        body: const AppListSkeleton(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.profile)),
        body: AppErrorState(
          error: error,
          fallbackMessage: isMe
              ? l10n.myProfileLoadFailed
              : l10n.profileLoadFailed,
          retryLabel: l10n.retry,
          onRetry: () => ref.invalidate(profileDetailProvider(resolvedId)),
        ),
      ),
      data: (profile) => Scaffold(
        body: RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(profileDetailProvider(resolvedId)),
          child: _content(l10n, profile, me: me, isMe: isMe),
        ),
      ),
    );
  }

  Widget _content(
    AppLocalizations l10n,
    ProfileEntity profile, {
    required UserEntity? me,
    required bool isMe,
  }) {
    final specialization = profile.specialization?.trim();
    final bio = profile.bio?.trim();

    // The header falls back to the specialization when the name is already
    // the handle, so the row below would otherwise say the same thing twice.
    final subtitle = _subtitleOf(profile);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: ProfileHeader(
            profile: profile,
            title: _titleOf(profile),
            subtitle: subtitle,
            topPadding: MediaQuery.paddingOf(context).top,
            onBack: _back,
            onAvatarTap: profile.hasAvatar
                ? () => context.push(_avatarLocation(profile.id, isMe: isMe))
                : null,
            avatarAction: isMe
                ? AvatarPickerButton(profileId: profile.id)
                : null,
            trailing: isMe
                ? IconButton(
                    tooltip: l10n.editProfile,
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => context.push(ProfileEditRoute.location),
                  )
                : null,
          ),
        ),

        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMe)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: AvatarUploadStatus(),
                ),
              const SizedBox(height: 8),

              AppQuickActionsRow(
                actions: _actions(l10n, profile, isMe: isMe),
              ),

              if (specialization != null &&
                  specialization.isNotEmpty &&
                  specialization != subtitle)
                _InfoTile(
                  icon: Icons.work_outline,
                  label: l10n.specialization,
                  value: specialization,
                ),

              if (profile.dateBirthday != null)
                _InfoTile(
                  icon: Icons.cake_outlined,
                  label: l10n.profileBirthday,
                  value: MaterialLocalizations.of(
                    context,
                  ).formatFullDate(profile.dateBirthday!),
                ),

              if (bio != null && bio.isNotEmpty) ...[
                const Divider(height: 1),
                _Section(title: l10n.profileAbout, child: SelectableText(bio)),
              ],

              if (profile.skills.isNotEmpty) ...[
                const Divider(height: 1),
                _Section(
                  title: l10n.profileSkills,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final skill in profile.skills)
                        Chip(
                          label: Text(skill),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ],

              if (profile.contacts.isNotEmpty) ...[
                const Divider(height: 1),
                _SectionHeading(title: l10n.profileContacts),
                for (final contact in profile.contacts)
                  _ContactTile(
                    link: profileContactLinkOf(contact),
                    onOpen: _openUri,
                    onCopy: _copy,
                  ),
                const SizedBox(height: 8),
              ],

              if (_isBlank(profile))
                _EmptyProfileNote(
                  message: isMe
                      ? l10n.profileEmptyHintSelf
                      : l10n.profileEmptyHintOther,
                ),

              if (isMe) ...[
                const Divider(height: 1),
                _AccountRows(user: me),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  bool _isBlank(ProfileEntity profile) {
    final bio = profile.bio?.trim() ?? '';
    final specialization = profile.specialization?.trim() ?? '';
    return bio.isEmpty &&
        specialization.isEmpty &&
        profile.skills.isEmpty &&
        profile.contacts.isEmpty &&
        profile.dateBirthday == null;
  }

  /// The display name, falling back to the handle — which every profile has.
  String _titleOf(ProfileEntity profile) {
    final name = profile.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return '@${profile.username}';
  }

  /// The handle, unless it is already the title, in which case the
  /// specialization — whichever second line actually says something new.
  String _subtitleOf(ProfileEntity profile) {
    final name = profile.displayName?.trim() ?? '';
    if (name.isNotEmpty) return '@${profile.username}';
    return profile.specialization?.trim() ?? '';
  }

  String _avatarLocation(int profileId, {required bool isMe}) {
    return isMe
        ? ProfileAvatarRoute.location
        : ProfileDetailAvatarRoute.locationOf(profileId);
  }

  List<AppQuickAction> _actions(
    AppLocalizations l10n,
    ProfileEntity profile, {
    required bool isMe,
  }) {
    if (isMe) {
      return [
        AppQuickAction(
          icon: Icons.edit_outlined,
          label: l10n.editProfile,
          onPressed: () => context.push(ProfileEditRoute.location),
        ),
        AppQuickAction(
          icon: Icons.ios_share,
          label: l10n.profileShareAction,
          onPressed: () => _share(profile),
        ),
      ];
    }

    return [
      AppQuickAction(
        icon: Icons.chat_bubble_outline,
        label: l10n.sendMessageAction,
        onPressed: _isOpeningChat ? null : () => _openDirect(profile.id),
      ),
      AppQuickAction(
        icon: Icons.call_outlined,
        label: l10n.callTitle,
        onPressed: _isOpeningChat
            ? null
            : () => _openDirect(profile.id, call: true),
      ),
      AppQuickAction(
        icon: Icons.ios_share,
        label: l10n.profileShareAction,
        onPressed: () => _share(profile),
      ),
    ];
  }

  /// Both "message" and "call" go through the same 1:1 chat, because a call
  /// is a room inside a chat and there is no person-to-person call endpoint
  /// (api-docs §5.6).
  Future<void> _openDirect(int userId, {bool call = false}) async {
    setState(() => _isOpeningChat = true);

    final result = await resolveDirectChatWith(ref, userId);

    if (!mounted) return;
    setState(() => _isOpeningChat = false);

    result.match(
      (failure) => AppSnackbar.quiet(
        context,
        chatFailureMessage(failure) ??
            friendlyFailureMessage(
              failure,
              fallback: AppLocalizations.of(context).startChatFailed,
            ),
      ),
      (chatId) => context.push(
        call
            ? ChatCallRoute.locationOf(chatId)
            : ChatDetailRoute(chatId).location,
      ),
    );
  }

  /// Copies the link rather than opening a system share sheet: the app has
  /// no share plugin, and a clipboard copy works on every platform it ships
  /// to. The link itself only opens in this app — see [ProfileShareLink].
  Future<void> _share(ProfileEntity profile) async {
    final l10n = AppLocalizations.of(context);

    await Clipboard.setData(
      ClipboardData(
        text: ProfileShareLink.messageFor(
          profile.id,
          displayName: profile.displayName,
          username: profile.username,
        ),
      ),
    );

    if (!mounted) return;
    AppSnackbar.quiet(context, l10n.profileShareCopied);
  }

  Future<void> _openUri(Uri uri) async {
    final l10n = AppLocalizations.of(context);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    AppSnackbar.quiet(context, l10n.profileOpenLinkFailed);
  }

  Future<void> _copy(String value) async {
    final l10n = AppLocalizations.of(context);

    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;

    AppSnackbar.quiet(context, l10n.profileContactCopied);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(ProfilesRoute.location);
    }
  }
}

/// One fact about a person: an icon, what it is, and what it says.
class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(value),
      subtitle: Text(label, style: theme.textTheme.labelSmall),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(title: title),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: child,
        ),
      ],
    );
  }
}

/// One `ProfileLinkDTO`, as something to tap.
class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.link,
    required this.onOpen,
    required this.onCopy,
  });

  final ProfileContactLink link;
  final Future<void> Function(Uri uri) onOpen;
  final Future<void> Function(String value) onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final uri = link.uri;

    return ListTile(
      leading: Icon(link.icon, color: theme.colorScheme.onSurfaceVariant),
      title: Text(
        link.value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: uri == null
            ? null
            : TextStyle(color: theme.colorScheme.primary),
      ),
      subtitle: Text(link.label, style: theme.textTheme.labelSmall),
      // A row with nothing to open still copies, which is the only thing
      // left to do with, say, a Discord handle.
      onTap: uri == null ? () => onCopy(link.value) : () => onOpen(uri),
      trailing: IconButton(
        tooltip: l10n.profileCopyAction,
        icon: const Icon(Icons.copy_outlined, size: 18),
        onPressed: () => onCopy(link.value),
      ),
    );
  }
}

class _EmptyProfileNote extends StatelessWidget {
  const _EmptyProfileNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Account, settings and devices — the three rows that only belong on one's
/// own profile.
class _AccountRows extends ConsumerWidget {
  const _AccountRows({required this.user});

  final UserEntity? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // `GET /users/sessions/` answers a bare `SessionDTO[]` rather than a
    // PageResult, so the count is just the length (api-docs §3.12, §0.16).
    final sessions = ref.watch(mySessionsProvider);
    final deviceCount = sessions.value?.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(l10n.profileAccount),
          subtitle: Text(_accountLine(l10n)),
        ),
        const Divider(height: 1, indent: 16),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.settings),
          subtitle: Text(l10n.profileSettingsHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(SettingsRoute.location),
        ),
        const Divider(height: 1, indent: 16),
        ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: Text(l10n.myDevices),
          subtitle: Text(
            sessions.hasError
                ? l10n.devicesLoadFailed
                : deviceCount == null
                ? l10n.loading
                : l10n.devicesCount(deviceCount),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(SessionsRoute.location),
        ),
      ],
    );
  }

  String _accountLine(AppLocalizations l10n) {
    final account = user;
    if (account == null) return l10n.profileAccountNoEmail;

    final parts = <String>[
      if (account.username.trim().isNotEmpty) '@${account.username.trim()}',
      if (account.email.trim().isNotEmpty) account.email.trim(),
    ];

    return parts.isEmpty ? l10n.profileAccountNoEmail : parts.join(' · ');
  }
}
