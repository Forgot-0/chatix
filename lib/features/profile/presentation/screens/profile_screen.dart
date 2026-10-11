import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/localization/app_date_format.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/core/ui/widgets/app_quick_actions.dart';
import 'package:chatix/features/auth/domain/entities/user_entity.dart';
import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/auth/presentation/providers/auth_providers.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/chat_presence_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_state_actions.dart';
import 'package:chatix/features/chat/presentation/providers/direct_chat_opener.dart';
import 'package:chatix/features/chat/presentation/utils/chat_mute_options.dart';
import 'package:chatix/features/chat/presentation/utils/chat_shared_content.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_header_menu.dart';
import 'package:chatix/features/chat/presentation/widgets/profile/chat_shared_content_view.dart';
import 'package:chatix/features/contacts/domain/entities/contact.dart';
import 'package:chatix/features/contacts/presentation/providers/blocked_users_providers.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_lifecycle_provider.dart';
import 'package:chatix/features/contacts/presentation/providers/contacts_providers.dart';
import 'package:chatix/features/contacts/presentation/widgets/block_actions.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_actions.dart';
import 'package:chatix/features/profile/domain/entities/profile_entity.dart';
import 'package:chatix/features/profile/presentation/providers/profile_detail_provider.dart';
import 'package:chatix/features/profile/presentation/utils/profile_contact_link.dart';
import 'package:chatix/features/profile/presentation/utils/profile_share_link.dart';
import 'package:chatix/features/profile/presentation/utils/profile_view.dart';
import 'package:chatix/features/profile/presentation/widgets/avatar_picker_widget.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_header.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_info_card.dart';
import 'package:chatix/features/profile/presentation/widgets/profile_qr_sheet.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// Everything about one person on one page — whichever way they were
/// reached: from the contacts, from a direct chat's header, from a group's
/// member list or from an `@mention`.
///
/// The same screen serves "me" and "them": the difference is which round
/// buttons sit under the header and whether the account card is there at
/// all, not two near-identical layouts drifting apart. When there is a
/// direct chat with the person, what it has shared hangs off the bottom.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.profileId, this.chatId});

  /// Null means the signed-in user's own profile.
  final int? profileId;

  /// The direct chat this profile is the info page of, when it was opened
  /// from that chat's header. Otherwise the chat is looked up among the
  /// loaded ones, and there may be none.
  final String? chatId;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Where the "Mute" and "More" menus open from.
  final GlobalKey _muteKey = GlobalKey();
  final GlobalKey _moreKey = GlobalKey();

  /// True while a direct chat is being found or created, so neither the
  /// message nor the call action can be asked for twice.
  bool _isOpeningChat = false;

  /// The chat presence was last asked for. Presence costs a request
  /// (api-docs §5.3), so it is asked once per chat this screen shows.
  String? _presenceAskedFor;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: SharedContentTab.values.length,
      vsync: this,
    );
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {});
  }

  SharedContentTab get _tab => SharedContentTab.values[_tabController.index];

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
          onRefresh: () async => _refresh(resolvedId),
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
    // In the owner's book or not: decides between "add" and "remove", and
    // puts the name they gave this person at the top, as Telegram does.
    final contact = isMe ? null : ref.watch(contactOfProvider(profile.id));
    final chatId = isMe ? null : _directChatIdOf(profile.id);
    final blocked = !isMe && ref.watch(isUserBlockedProvider(profile.id));

    final online = chatId == null
        ? null
        : ref.watch(chatPeerOnlineProvider(chatId));
    final muted = chatId == null
        ? null
        : ref.watch(chatRowStateProvider(chatId))?.isMutedByMe;
    _askPresence(chatId);

    final presence = ProfilePresence.of(isMe: isMe, online: online);
    final facts = ProfileFacts.of(profile);
    final title = contact?.localName ?? _titleOf(profile);

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: ProfileHeader(
            profile: profile,
            title: title,
            subtitle: _presenceLabel(l10n, presence),
            subtitleIsAccent: presence == ProfilePresence.online,
            topPadding: MediaQuery.paddingOf(context).top,
            onBack: _back,
            onAvatarTap: profile.hasAvatar
                ? () => context.push(_avatarLocation(profile.id, isMe: isMe))
                : null,
            avatarAction: isMe
                ? AvatarPickerButton(profileId: profile.id)
                : null,
            trailing: isMe
                ? TextButton(
                    onPressed: () => context.push(ProfileEditRoute.location),
                    child: Text(l10n.profileEditAction),
                  )
                : null,
          ),
        ),

        SliverContentWidth(
          maxWidth: AppContentWidths.profile,
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isMe)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.x6),
                    child: AvatarUploadStatus(),
                  ),
                const SizedBox(height: AppSpacing.x2),

                AppQuickActionsRow(
                  actions: [
                    for (final action in ProfileActions.quickFor(
                      isMe: isMe,
                      muted: muted,
                    ))
                      _quickAction(
                        l10n,
                        action,
                        profile: profile,
                        title: title,
                        contact: contact,
                        chatId: chatId,
                        blocked: blocked,
                        muted: muted == true,
                      ),
                  ],
                ),

                if (blocked)
                  _Inset(
                    child: _BlockedNotice(userId: profile.id, name: title),
                  ),

                _Inset(
                  child: ProfileInfoCard(
                    children: _facts(
                      l10n,
                      facts,
                      profile: profile,
                      title: title,
                      email: isMe ? me?.email : null,
                    ),
                  ),
                ),

                if (facts.isBlank)
                  _EmptyProfileNote(
                    message: isMe
                        ? l10n.profileEmptyHintSelf
                        : l10n.profileEmptyHintOther,
                  ),

                if (isMe) const _Inset(child: _AccountCard()),

                SizedBox(
                  height: chatId == null ? AppSpacing.x8 : AppSpacing.x2,
                ),
              ],
            ),
          ),
        ),

        if (chatId != null) ..._sharedContent(l10n, chatId),
      ],
    );
  }

  /// The direct chat with [userId]: the one this page was opened from, or
  /// one among the loaded chats. Only looked up when not given, so opening
  /// a chat's own info page never starts a fetch of the whole chat list.
  String? _directChatIdOf(int userId) {
    final given = widget.chatId;
    if (given != null) return given;
    return ref.watch(directChatIdsProvider.select((chats) => chats[userId]));
  }

  /// Asks for presence once the chat to read it from is known — which may
  /// be a frame or two in, when the chat list arrives after the profile.
  void _askPresence(String? chatId) {
    if (chatId == null || chatId == _presenceAskedFor) return;
    _presenceAskedFor = chatId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(chatPresenceProvider.notifier).ensureFresh(chatId);
    });
  }

  Future<void> _refresh(int profileId) async {
    ref.invalidate(profileDetailProvider(profileId));

    final chatId = _presenceAskedFor;
    if (chatId == null) return;
    final presence = ref.read(chatPresenceProvider.notifier)..invalidate();
    presence.ensureFresh(chatId);
  }

  String _presenceLabel(AppLocalizations l10n, ProfilePresence presence) {
    return switch (presence) {
      ProfilePresence.online => l10n.chatStatusOnline,
      ProfilePresence.recently => l10n.profileStatusRecently,
      ProfilePresence.unknown => '',
    };
  }

  /// The display name, falling back to the handle — which every profile has.
  String _titleOf(ProfileEntity profile) {
    final name = profile.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return '@${profile.username}';
  }

  String _avatarLocation(int profileId, {required bool isMe}) {
    final chatId = widget.chatId;
    if (chatId != null) {
      return ChatInfoAvatarRoute.locationOf(chatId, profileId);
    }
    return isMe
        ? ProfileAvatarRoute.location
        : ProfileDetailAvatarRoute.locationOf(profileId);
  }

  // ------------------------------------------------------------ the facts

  List<Widget> _facts(
    AppLocalizations l10n,
    ProfileFacts facts, {
    required ProfileEntity profile,
    required String title,
    required String? email,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final birthday = facts.birthday;
    final specialization = facts.specialization;
    final address = email?.trim();

    return [
      ProfileInfoRow(
        value: facts.handle,
        caption: l10n.username,
        onTap: () => _copy(facts.handle, done: l10n.profileUsernameCopied),
        onLongPress: () => _showQr(profile, title),
        trailing: IconButton(
          tooltip: l10n.profileActionQr,
          color: scheme.primary,
          icon: const Icon(Icons.qr_code_2),
          onPressed: () => _showQr(profile, title),
        ),
      ),

      if (facts.bio case final bio?)
        ProfileInfoRow(
          value: bio,
          caption: l10n.profileAbout,
          maxLines: null,
          onLongPress: () => _copy(bio, done: l10n.profileContactCopied),
        ),

      if (birthday != null)
        ProfileInfoRow(
          // `date_birthday` always carries a year today (api-docs §4.3); a
          // profile that could hide it would pass null and lose the age.
          value: AppDateFormat.of(context).birthday(
            day: birthday.day,
            month: birthday.month,
            year: birthday.year,
          ),
          caption: l10n.profileBirthday,
        ),

      for (final entity in facts.links)
        _linkRow(l10n, profileContactLinkOf(entity)),

      if (specialization != null)
        ProfileInfoRow(value: specialization, caption: l10n.specialization),

      if (facts.skills.isNotEmpty)
        ProfileInfoRow(
          value: facts.skills.join(', '),
          caption: l10n.profileSkills,
          maxLines: null,
        ),

      // Only on one's own profile: `GET /users/me/` is the only place the
      // address exists, and it is nobody else's business (api-docs §3.9).
      if (address != null && address.isNotEmpty)
        ProfileInfoRow(value: address, caption: l10n.email),
    ];
  }

  /// One `ProfileLinkDTO`: tapped, it opens; one with nothing to open — a
  /// Discord handle — copies instead. Held, it always copies.
  Widget _linkRow(AppLocalizations l10n, ProfileContactLink link) {
    final uri = link.uri;

    return ProfileInfoRow(
      value: link.value,
      caption: link.label,
      valueColor: uri == null ? null : Theme.of(context).colorScheme.primary,
      onTap: uri == null
          ? () => _copy(link.value, done: l10n.profileContactCopied)
          : () => _openUri(uri),
      onLongPress: () => _copy(link.value, done: l10n.profileContactCopied),
    );
  }

  // ---------------------------------------------------- the round buttons

  AppQuickAction _quickAction(
    AppLocalizations l10n,
    ProfileQuickAction action, {
    required ProfileEntity profile,
    required String title,
    required Contact? contact,
    required String? chatId,
    required bool blocked,
    required bool muted,
  }) {
    final enabled = ProfileActions.isEnabled(
      action,
      busy: _isOpeningChat,
      blocked: blocked,
      hasDirectChat: chatId != null,
    );

    VoidCallback? when(VoidCallback callback) => enabled ? callback : null;

    return switch (action) {
      ProfileQuickAction.message => AppQuickAction(
        icon: Icons.chat_bubble_outline,
        label: l10n.sendMessageAction,
        onPressed: when(() => _openDirect(profile.id)),
      ),
      ProfileQuickAction.call => AppQuickAction(
        icon: Icons.call_outlined,
        label: l10n.callTitle,
        onPressed: when(() => _openDirect(profile.id, call: true)),
      ),
      ProfileQuickAction.mute || ProfileQuickAction.unmute => AppQuickAction(
        icon: muted
            ? Icons.notifications_off_outlined
            : Icons.notifications_none_outlined,
        label: muted ? l10n.profileActionUnmute : l10n.profileActionMute,
        anchorKey: _muteKey,
        onPressed: when(() => _setMuted(chatId!, mute: !muted)),
      ),
      ProfileQuickAction.more => AppQuickAction(
        icon: Icons.more_horiz,
        label: l10n.profileActionMore,
        anchorKey: _moreKey,
        onPressed: when(
          () => _openMore(
            profile,
            title: title,
            contact: contact,
            blocked: blocked,
          ),
        ),
      ),
      ProfileQuickAction.share => AppQuickAction(
        icon: Icons.ios_share,
        label: l10n.profileShareAction,
        onPressed: when(() => _share(profile)),
      ),
      ProfileQuickAction.qr => AppQuickAction(
        icon: Icons.qr_code_2,
        label: l10n.profileActionQr,
        onPressed: when(() => _showQr(profile, title)),
      ),
    };
  }

  /// Both "message" and "call" go through the same 1:1 chat, because a call
  /// is a room inside a chat and there is no person-to-person call endpoint
  /// (api-docs §5.6).
  Future<void> _openDirect(int userId, {bool call = false}) async {
    // Opened from that very chat: "message" is the way back to it.
    final known = widget.chatId;
    if (known != null) {
      if (call) {
        context.push(ChatCallRoute.locationOf(known));
      } else {
        context.go(ChatDetailRoute(known).location);
      }
      return;
    }

    setState(() => _isOpeningChat = true);
    final result = await resolveDirectChatWith(ref, userId);
    if (!mounted) return;
    setState(() => _isOpeningChat = false);

    result.match(
      (failure) => AppSnackbar.failure(
        context,
        chatFailureMessage(failure) ??
            friendlyFailureMessage(
              failure,
              l10n: AppLocalizations.of(context),
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

  /// Silences the direct chat for as long as is picked, or lets it speak
  /// again. The server keeps a deadline, not a switch (api-docs §5.2).
  Future<void> _setMuted(String chatId, {required bool mute}) async {
    final l10n = AppLocalizations.of(context);

    DateTime? until;
    if (mute) {
      final option = await showMenu<ChatMuteOption>(
        context: context,
        position: _anchorBelow(_muteKey),
        constraints: _menuConstraints,
        items: [
          PopupMenuItem<ChatMuteOption>(
            enabled: false,
            child: ChatMenuHeading(label: l10n.chatMenuMute),
          ),
          for (final option in ChatMuteOption.values)
            PopupMenuItem<ChatMuteOption>(
              value: option,
              child: ChatMenuEntry(
                icon: option == ChatMuteOption.forever
                    ? Icons.notifications_off_outlined
                    : Icons.schedule,
                label: option.label(l10n),
              ),
            ),
        ],
      );
      if (option == null || !mounted) return;
      until = option.untilFrom(DateTime.now());
    }

    final failure = await ref
        .read(chatStateActionsProvider)
        .setMuted(chatId, muted: mute, until: until);
    if (!mounted) return;

    _report(failure, done: mute ? l10n.chatMutedToast : l10n.chatUnmutedToast);
  }

  /// Share first, the address book in the middle, blocking last.
  Future<void> _openMore(
    ProfileEntity profile, {
    required String title,
    required Contact? contact,
    required bool blocked,
  }) async {
    final l10n = AppLocalizations.of(context);
    final actions = ProfileActions.menuFor(
      isContact: contact != null,
      isBlocked: blocked,
    );
    final firstDestructive = actions.indexWhere((it) => it.isDestructive);

    final picked = await showMenu<ProfileMenuAction>(
      context: context,
      position: _anchorBelow(_moreKey),
      constraints: _menuConstraints,
      items: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i == firstDestructive && i > 0) const PopupMenuDivider(),
          PopupMenuItem<ProfileMenuAction>(
            value: actions[i],
            child: ChatMenuEntry(
              icon: _menuIcon(actions[i]),
              label: _menuLabel(l10n, actions[i]),
              destructive: actions[i].isDestructive,
            ),
          ),
        ],
      ],
    );
    if (picked == null || !mounted) return;

    switch (picked) {
      case ProfileMenuAction.share:
        await _share(profile);
      case ProfileMenuAction.addContact:
        await ContactActions.addUser(context, ref, userId: profile.id);
      case ProfileMenuAction.rename:
        if (contact != null) await ContactActions.rename(context, contact);
      case ProfileMenuAction.removeContact:
        if (contact != null) {
          await ContactActions.delete(context, ref, contact);
        }
      case ProfileMenuAction.block:
        await BlockActions.block(context, ref, userId: profile.id, name: title);
      case ProfileMenuAction.unblock:
        await BlockActions.unblock(
          context,
          ref,
          userId: profile.id,
          name: title,
        );
    }
  }

  IconData _menuIcon(ProfileMenuAction action) => switch (action) {
    ProfileMenuAction.share => Icons.ios_share,
    ProfileMenuAction.addContact => Icons.person_add_alt_1_outlined,
    ProfileMenuAction.rename => Icons.edit_outlined,
    ProfileMenuAction.removeContact => Icons.person_remove_outlined,
    ProfileMenuAction.block => Icons.block,
    ProfileMenuAction.unblock => Icons.lock_open_outlined,
  };

  String _menuLabel(AppLocalizations l10n, ProfileMenuAction action) =>
      switch (action) {
        ProfileMenuAction.share => l10n.profileShareContact,
        ProfileMenuAction.addContact => l10n.profileAddToContacts,
        ProfileMenuAction.rename => l10n.contactsActionRename,
        ProfileMenuAction.removeContact => l10n.contactsRemoveFromContacts,
        ProfileMenuAction.block => l10n.blockUserAction,
        ProfileMenuAction.unblock => l10n.unblockUserAction,
      };

  static const BoxConstraints _menuConstraints = BoxConstraints(
    minWidth: AppMenuSizes.minWidth,
    maxWidth: AppMenuSizes.maxWidth,
  );

  /// Under the button [key] is on, as wide as it — or in the top corner of
  /// the screen if the button is not laid out.
  RelativeRect _anchorBelow(GlobalKey key) {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final button = key.currentContext?.findRenderObject();
    if (button is! RenderBox) {
      return RelativeRect.fromRect(Rect.zero, Offset.zero & overlay.size);
    }

    final topLeft = button.localToGlobal(
      Offset(0, button.size.height),
      ancestor: overlay,
    );
    return RelativeRect.fromRect(
      topLeft & Size(button.size.width, 0),
      Offset.zero & overlay.size,
    );
  }

  // -------------------------------------------------------------- sharing

  /// The system share sheet where there is one, the clipboard elsewhere. The
  /// link opens only in this app — see [ProfileShareLink].
  Future<void> _share(ProfileEntity profile) async {
    final l10n = AppLocalizations.of(context);
    final text = ProfileShareLink.messageFor(
      profile.id,
      displayName: profile.displayName,
      username: profile.username,
    );

    final sharer = ref.read(fileSharerProvider);
    if (sharer.isSupported) {
      final box = _moreKey.currentContext?.findRenderObject();
      final origin = box is RenderBox
          ? box.localToGlobal(Offset.zero) & box.size
          : null;
      try {
        await sharer.shareText(text, origin: origin);
        return;
      } catch (_) {
        // No share sheet after all: the clipboard still works.
      }
    }

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppSnackbar.quiet(context, l10n.profileShareCopied);
  }

  Future<void> _showQr(ProfileEntity profile, String title) {
    return showProfileQrSheet(
      context,
      profileId: profile.id,
      name: title,
      username: profile.username,
      onShare: () => _share(profile),
    );
  }

  Future<void> _openUri(Uri uri) async {
    final l10n = AppLocalizations.of(context);

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !mounted) return;

    AppSnackbar.failure(context, l10n.profileOpenLinkFailed);
  }

  Future<void> _copy(String value, {required String done}) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    AppSnackbar.quiet(context, done);
  }

  void _report(Failure? failure, {required String done}) {
    if (failure == null) {
      AppSnackbar.quiet(context, done);
      return;
    }
    final l10n = AppLocalizations.of(context);
    AppSnackbar.failure(
      context,
      friendlyFailureMessage(failure, l10n: l10n, fallback: l10n.errorOccurred),
    );
  }

  // ------------------------------------------------------- shared content

  /// What the direct chat has shared, in four tabs at the foot of the page.
  /// The tabs choose which sliver goes at the bottom of the same scroll, so
  /// the header collapses once for the whole page.
  List<Widget> _sharedContent(AppLocalizations l10n, String chatId) {
    final content = ref.watch(chatSharedContentProvider(chatId));

    return [
      SliverContentWidth(
        maxWidth: AppContentWidths.profile,
        sliver: SliverPersistentHeader(
          pinned: true,
          delegate: SharedContentTabsHeader(
            sharedContentTabBar(
              l10n,
              controller: _tabController,
              content: content,
            ),
          ),
        ),
      ),
      SliverContentWidth(
        maxWidth: AppContentWidths.profile,
        sliver: ChatSharedContentSliver(
          key: ValueKey<SharedContentTab>(_tab),
          chatId: chatId,
          tab: _tab,
          content: content,
        ),
      ),
    ];
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final chatId = widget.chatId;
    context.go(
      chatId == null
          ? ProfilesRoute.location
          : ChatDetailRoute(chatId).location,
    );
  }
}

/// The page's side margin around a card, and the gap under it.
class _Inset extends StatelessWidget {
  const _Inset({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        0,
        AppSpacing.x4,
        AppSpacing.x3,
      ),
      child: child,
    );
  }
}

/// "You blocked this user", with the way back right beside it.
class _BlockedNotice extends ConsumerWidget {
  const _BlockedNotice({required this.userId, required this.name});

  final int userId;
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final danger = ChatixTheme.of(context).danger;
    final busy = ref.watch(isBlockBusyProvider(userId));

    return Material(
      color: Color.alphaBlend(
        danger.withValues(alpha: ProfileLayout.blockedTint),
        profileCardColor(theme),
      ),
      borderRadius: BorderRadius.circular(ProfileLayout.cardRadius),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          AppSpacing.x4,
          AppSpacing.x2,
          AppSpacing.x2,
          AppSpacing.x2,
        ),
        child: Row(
          children: [
            Icon(Icons.block, color: danger, size: AppMenuSizes.iconSize),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                l10n.profileBlockedNotice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => BlockActions.unblock(
                      context,
                      ref,
                      userId: userId,
                      name: name,
                    ),
              child: Text(l10n.unblockUserAction),
            ),
          ],
        ),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x6,
        0,
        AppSpacing.x6,
        AppSpacing.x4,
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Settings and devices — the rows that only belong on one's own profile.
class _AccountCard extends ConsumerWidget {
  const _AccountCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    // `GET /users/sessions/` answers a bare `SessionDTO[]` rather than a
    // PageResult, so the count is just the length (api-docs §3.12, §0.16).
    final sessions = ref.watch(mySessionsProvider);
    final deviceCount = sessions.value?.length;

    return ProfileInfoCard(
      children: [
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.settings),
          subtitle: Text(l10n.settingsRowHint),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push(SettingsRoute.location),
        ),
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
}
