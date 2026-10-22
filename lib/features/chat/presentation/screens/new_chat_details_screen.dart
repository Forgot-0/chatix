import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/error/failure_messages.dart';
import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/app_snackbar.dart';
import 'package:chatix/core/ui/widgets/app_content_width.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';
import 'package:chatix/features/chat/presentation/providers/new_chat_provider.dart';
import 'package:chatix/features/chat/presentation/utils/new_chat_draft.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/chat_photo_picker.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_people.dart';
import 'package:chatix/features/chat/presentation/widgets/new_chat/new_chat_step_scaffold.dart';
import 'package:chatix/features/contacts/presentation/utils/contact_labels.dart';
import 'package:chatix/features/contacts/presentation/widgets/contact_tile.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// The details of a new group or channel: its picture, its name — the one
/// thing it cannot go without — and what it is about. A channel also says
/// here whether anyone can find it.
///
/// For a group this is the last step and its button creates the chat; for a
/// channel the people come after, and are optional.
class NewChatDetailsScreen extends ConsumerStatefulWidget {
  const NewChatDetailsScreen({super.key, required this.kind});

  final NewChatKind kind;

  @override
  ConsumerState<NewChatDetailsScreen> createState() =>
      _NewChatDetailsScreenState();
}

class _NewChatDetailsScreenState extends ConsumerState<NewChatDetailsScreen> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  final FocusNode _nameFocus = FocusNode();

  /// The name's error shows only once the reader has tried to go on: an
  /// empty field is not a mistake before then.
  bool _triedToContinue = false;

  NotifierProvider<NewChatController, NewChatState> get _flow =>
      newChatProviderOf(widget.kind);

  bool get _isGroup => widget.kind == NewChatKind.group;

  @override
  void initState() {
    super.initState();
    // Seeded from the draft, so coming back from the next step finds what
    // was typed.
    final draft = ref.read(_flow).draft;
    _name = TextEditingController(text: draft.name);
    _description = TextEditingController(text: draft.description);
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final draft = ref.read(_flow).draft;
    if (draft.detailsProblem != null) {
      setState(() => _triedToContinue = true);
      _nameFocus.requestFocus();
      return;
    }

    if (_isGroup) {
      await submitNewChat(context, ref, widget.kind);
    } else {
      context.push(NewChannelSubscribersRoute.location);
    }
  }

  String? _nameError(AppLocalizations l10n, NewChatDraft draft) {
    if (!_triedToContinue) return null;
    return switch (draft.detailsProblem) {
      NewChatProblem.nameMissing =>
        _isGroup ? l10n.newGroupNameRequired : l10n.newChannelNameRequired,
      NewChatProblem.nameTooLong => l10n.apiErrorTooLongGeneric,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = ref.watch(_flow);
    final draft = state.draft;
    final controller = ref.read(_flow.notifier);
    final busy = state.isSubmitting;

    return NewChatStepScaffold(
      title: _isGroup ? l10n.newGroup : l10n.newChannel,
      actionLabel: _isGroup ? l10n.create : l10n.next,
      actionIcon: _isGroup ? Icons.check_rounded : Icons.arrow_forward_rounded,
      onAction: _continue,
      busy: busy,
      body: AppContentWidth(
        child: ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.x4,
            bottom: ChatsListLayout.fabClearance,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  NewChatPhotoButton(
                    photo: draft.photo,
                    enabled: !busy,
                    onChanged: controller.setPhoto,
                  ),
                  const SizedBox(width: AppSpacing.x4),
                  Expanded(
                    child: Padding(
                      // The field's box centred on the photo, its error
                      // free to hang below.
                      padding: const EdgeInsets.only(top: AppSpacing.x1),
                      child: TextField(
                        controller: _name,
                        focusNode: _nameFocus,
                        enabled: !busy,
                        autofocus: draft.name.isEmpty,
                        onChanged: (value) {
                          controller.setName(value);
                          if (_triedToContinue) setState(() {});
                        },
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            CreateChatUseCase.maxNameLength,
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: _isGroup
                              ? l10n.newGroupNameLabel
                              : l10n.newChannelNameLabel,
                          errorText: _nameError(l10n, draft),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.x4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: TextField(
                controller: _description,
                enabled: !busy,
                onChanged: controller.setDescription,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(
                    CreateChatUseCase.maxDescriptionLength,
                  ),
                ],
                decoration: InputDecoration(
                  labelText: l10n.newChatDescriptionLabel,
                  alignLabelWithHint: true,
                  helperText: _isGroup
                      ? l10n.newGroupDescriptionHelper
                      : l10n.newChannelDescriptionHelper,
                  helperMaxLines: 2,
                ),
              ),
            ),
            if (_isGroup)
              _MembersSummary(members: draft.members)
            else
              _ChannelVisibility(
                isPublic: draft.isPublic,
                enabled: !busy,
                onChanged: controller.setPublic,
              ),
          ],
        ),
      ),
    );
  }
}

/// Who the group starts with, under the form — as Telegram shows them —
/// so the reader sees what "Create" will make.
class _MembersSummary extends StatelessWidget {
  const _MembersSummary({required this.members});

  final List<NewChatMember> members;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.x2),
        ContactSectionHeader(title: l10n.membersCount(members.length)),
        if (members.isEmpty)
          PeopleNote(text: l10n.newGroupNoMembers)
        else
          for (final member in members)
            // A list to read, not to act on: the people step is where the
            // picks change.
            IgnorePointer(
              key: ValueKey<int>(member.userId),
              child: PersonRow(
                avatar: newChatMemberAvatar(member),
                name: member.name,
                subtitle: PersonRowSubtitle.handle(
                  member.name == '@${member.username}' ? null : member.username,
                ),
                onTap: () {},
              ),
            ),
      ],
    );
  }
}

/// Public or private, each with what it means for the people who will come
/// across the channel.
class _ChannelVisibility extends StatelessWidget {
  const _ChannelVisibility({
    required this.isPublic,
    required this.enabled,
    required this.onChanged,
  });

  final bool isPublic;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.x2),
        ContactSectionHeader(title: l10n.newChannelVisibilityTitle),
        RadioGroup<bool>(
          groupValue: isPublic,
          onChanged: (value) {
            if (enabled && value != null) onChanged(value);
          },
          child: Column(
            children: [
              RadioListTile<bool>(
                value: false,
                enabled: enabled,
                title: Text(l10n.newChannelPrivate),
                subtitle: Text(l10n.newChannelPrivateHint),
              ),
              RadioListTile<bool>(
                value: true,
                enabled: enabled,
                title: Text(l10n.newChannelPublic),
                subtitle: Text(l10n.newChannelPublicHint),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Creates the chat the flow for [kind] has been filling in, and goes to it.
///
/// Shared by the two last steps — a group's details, a channel's people —
/// so the outcome reads the same from either: the chat opens straight away,
/// and whatever did not make it — people whose privacy keeps them out, a
/// picture that did not upload — is said on the way in.
Future<void> submitNewChat(
  BuildContext context,
  WidgetRef ref,
  NewChatKind kind,
) async {
  final l10n = AppLocalizations.of(context);
  final result = await ref.read(newChatProviderOf(kind).notifier).submit();
  if (!context.mounted) return;

  result.match(
    (failure) {
      if (failure is CancelledFailure) return;
      if (failure is NewChatValidationFailure) {
        // Only reachable by a step skipped through a link: the details
        // step is where a name is asked for.
        context.go(
          kind == NewChatKind.group
              ? NewGroupDetailsRoute.location
              : NewChannelRoute.location,
        );
        return;
      }
      AppSnackbar.failure(
        context,
        chatFailureMessage(failure) ??
            friendlyFailureMessage(
              failure,
              l10n: l10n,
              fallback: l10n.createChatFailed,
            ),
      );
    },
    (created) {
      // Said before leaving: the messenger outlives this page and shows it
      // over the chat.
      if (created.notAdded.isNotEmpty) {
        AppSnackbar.failure(
          context,
          l10n.newChatSomeNotAdded(
            created.notAdded.map((member) => member.name).join(', '),
          ),
        );
      } else if (created.photoFailed) {
        AppSnackbar.failure(context, l10n.newChatPhotoFailed);
      }
      // `go`: back from the new chat is the chats list, not the steps.
      context.go(ChatDetailRoute(created.chatId).location);
    },
  );
}
