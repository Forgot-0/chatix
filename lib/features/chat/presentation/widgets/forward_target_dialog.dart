import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_list_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_title.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_avatar.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the forward picker hands back: where to send, and the optional comment
/// the API accepts alongside a forward (api-docs §5.4 `ForwardMessageRequest`).
class ForwardTarget {
  const ForwardTarget({required this.chatId, this.comment});

  final String chatId;
  final String? comment;
}

/// Picks the chat a message is being forwarded into.
class ForwardTargetDialog extends ConsumerStatefulWidget {
  const ForwardTargetDialog({super.key, required this.excludeChatId});

  /// The chat the message is coming from: forwarding into it is a no-op, so
  /// it is not offered.
  final String excludeChatId;

  /// Opens the picker, returning null if it is dismissed.
  static Future<ForwardTarget?> pick(
    BuildContext context, {
    required String excludeChatId,
  }) {
    return showDialog<ForwardTarget>(
      context: context,
      builder: (dialogContext) =>
          ForwardTargetDialog(excludeChatId: excludeChatId),
    );
  }

  @override
  ConsumerState<ForwardTargetDialog> createState() =>
      ForwardTargetDialogState();
}

class ForwardTargetDialogState extends ConsumerState<ForwardTargetDialog> {
  final _commentController = TextEditingController();

  String? _selectedChatId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final chatId = _selectedChatId;
    if (chatId == null) return;

    final comment = _commentController.text.trim();
    Navigator.of(context).pop(
      ForwardTarget(chatId: chatId, comment: comment.isEmpty ? null : comment),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chats = ref.watch(chatListProvider);
    final l10n = AppLocalizations.of(context);
    final myUserId = ref.watch(authProvider).value?.id;

    return AlertDialog(
      title: Text(l10n.forwardTo),
      content: SizedBox(
        width: double.maxFinite,
        child: chats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Text(l10n.chatsLoadFailedShort),
          data: (state) {
            final targets = state.items
                .where((chat) => chat.id != widget.excludeChatId)
                .toList();
            if (targets.isEmpty) return Text(l10n.noOtherChats);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: targets.length,
                    itemBuilder: (context, index) {
                      final chat = targets[index];
                      final peer = chat.peerProfile(myUserId);
                      return ListTile(
                        selected: chat.id == _selectedChatId,
                        leading: peer == null
                            ? null
                            : ChatAvatar.profile(peer, size: ChatAvatarSize.xs),
                        title: Text(
                          chatTitleOf(chat, l10n, myUserId: myUserId),
                        ),
                        onTap: () => setState(() => _selectedChatId = chat.id),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    labelText: l10n.forwardComment,
                    isDense: true,
                  ),
                  maxLength: 4096,
                  maxLines: 2,
                  minLines: 1,
                  buildCounter:
                      (
                        _, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => null,
                ),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _selectedChatId == null ? null : _submit,
          child: Text(l10n.forwardAction),
        ),
      ],
    );
  }
}
