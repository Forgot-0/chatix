import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat/domain/entities/reaction_catalog.dart';
import 'package:chatix/features/chat/domain/usecases/create_chat_use_case.dart';

/// What the settings form refuses to send, and why.
enum ChatSettingsError {
  /// The name field was emptied on a chat that has one. `PATCH` cannot unset
  /// a name — `null` means "leave it alone" (api-docs §5.2) — so there is
  /// nothing to send that would do what the reader just asked for.
  nameCleared,

  /// Outside `0..86400` (api-docs §5.2), or not a number at all.
  slowModeOutOfRange,

  /// `reactions_mode: "some"` with an empty white list, which would turn
  /// reactions off by the back door.
  noReactionsPicked,
}

/// Exactly the fields that changed, ready for `PATCH /chats/{chat_id}/`.
///
/// Every field is null when it did not change, which is what the endpoint
/// reads as "leave this one alone".
class ChatSettingsPatch extends Equatable {
  const ChatSettingsPatch({
    this.name,
    this.description,
    this.isPublic,
    this.adminOnly,
    this.slowModeSeconds,
    this.reactionsMode,
    this.allowedReactions,
  });

  final String? name;
  final String? description;
  final bool? isPublic;
  final bool? adminOnly;
  final int? slowModeSeconds;
  final ChatReactionsMode? reactionsMode;
  final List<String>? allowedReactions;

  bool get isEmpty =>
      name == null &&
      description == null &&
      isPublic == null &&
      adminOnly == null &&
      slowModeSeconds == null &&
      reactionsMode == null &&
      allowedReactions == null;

  @override
  List<Object?> get props => [
    name,
    description,
    isPublic,
    adminOnly,
    slowModeSeconds,
    reactionsMode,
    allowedReactions,
  ];
}

/// The settings form's contents, as typed.
///
/// Separate from the widget so the one thing worth being sure about — that a
/// save sends the fields that changed and nothing else — can be checked
/// without a screen.
class ChatSettingsDraft extends Equatable {
  const ChatSettingsDraft({
    required this.name,
    required this.description,
    required this.isPublic,
    required this.adminOnly,
    required this.slowMode,
    required this.reactionsMode,
    required this.allowedReactions,
  });

  /// As typed. Trimming happens here, once, so the comparison against the
  /// chat sees the same string the server would be sent.
  final String name;
  final String description;

  final bool isPublic;
  final bool adminOnly;

  /// As typed, which may not be a number.
  final String slowMode;

  final ChatReactionsMode reactionsMode;
  final Set<String> allowedReactions;

  String get _name => name.trim();
  String get _description => description.trim();

  int? get slowModeSeconds => int.tryParse(slowMode.trim());

  /// The white list in catalog order, so the chat's own subset is ordered
  /// the way every picker draws it (api-docs §5.7.7).
  List<String> get orderedReactions => [
    for (final emoji in ReactionCatalog.all)
      if (allowedReactions.contains(emoji)) emoji,
  ];

  /// The first thing wrong with this draft, or null when there is nothing.
  ChatSettingsError? validate(ChatEntity chat) {
    if (_name.isEmpty && (chat.name ?? '').isNotEmpty) {
      return ChatSettingsError.nameCleared;
    }

    final seconds = slowModeSeconds;
    if (seconds == null ||
        seconds < 0 ||
        seconds > CreateChatUseCase.maxSlowModeSeconds) {
      return ChatSettingsError.slowModeOutOfRange;
    }

    if (reactionsMode == ChatReactionsMode.some && allowedReactions.isEmpty) {
      return ChatSettingsError.noReactionsPicked;
    }

    return null;
  }

  /// What to send. Assumes [validate] already passed.
  ChatSettingsPatch diff(ChatEntity chat) {
    final mode = reactionsMode;

    // The white list only travels with `some`. Under any other mode it is
    // not a setting the reader touched, and sending it would change
    // something they did not ask to change.
    final allowed = orderedReactions;
    final sendAllowed =
        mode == ChatReactionsMode.some &&
        !_sameSet(allowed, chat.allowedReactions);

    return ChatSettingsPatch(
      name: _name == (chat.name ?? '') ? null : _name,
      description: _description == (chat.description ?? '')
          ? null
          : _description,
      isPublic: isPublic == chat.isPublic ? null : isPublic,
      adminOnly: adminOnly == chat.adminOnly ? null : adminOnly,
      slowModeSeconds: slowModeSeconds == chat.slowModeSeconds
          ? null
          : slowModeSeconds,
      reactionsMode: mode == chat.reactionsMode ? null : mode,
      allowedReactions: sendAllowed ? allowed : null,
    );
  }

  static bool _sameSet(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final rest = b.toSet();
    return a.every(rest.contains);
  }

  @override
  List<Object?> get props => [
    name,
    description,
    isPublic,
    adminOnly,
    slowMode,
    reactionsMode,
    allowedReactions,
  ];
}
