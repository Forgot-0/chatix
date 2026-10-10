import 'package:equatable/equatable.dart';

import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// A draft as this device holds it.
///
/// The server keeps one too — `ChatDTO.draft`, written with
/// `PATCH /chats/{id}/state/ {draft}` (api-docs §5.2) — and this is the
/// offline copy of it: what the composer reads back instantly, what the chat
/// list shows before the network answers, and what is still waiting to be
/// written when there is no network at all.
class ChatDraft extends Equatable {
  const ChatDraft({
    required this.text,
    required this.updatedAt,
    this.syncedAt,
    this.pending = false,
  });

  /// Trimmed. Empty is a draft that was cleared here — sent, or erased —
  /// and is kept as a marker until the server has been told.
  final String text;

  /// When it was written on this device, by this device's clock.
  final DateTime updatedAt;

  /// The server's `draft_updated_at` for the version both sides last agreed
  /// on. While the server still reports exactly this, whatever is here now
  /// is newer than what it holds — whatever either clock says.
  final DateTime? syncedAt;

  /// Written here, not yet on the server.
  final bool pending;

  bool get isCleared => text.isEmpty;

  ChatDraft copyWith({
    String? text,
    DateTime? updatedAt,
    DateTime? syncedAt,
    bool? pending,
  }) {
    return ChatDraft(
      text: text ?? this.text,
      updatedAt: updatedAt ?? this.updatedAt,
      syncedAt: syncedAt ?? this.syncedAt,
      pending: pending ?? this.pending,
    );
  }

  @override
  List<Object?> get props => [text, updatedAt, syncedAt, pending];
}

/// A draft as the server last described it, from a chat row or from the
/// answer to a write.
class ServerDraft extends Equatable {
  const ServerDraft({this.text, this.updatedAt});

  /// Null when the response carried no per-user state at all —
  /// `ChatDetailDTO` has none (api-docs §5.2), and that says nothing about
  /// the draft.
  static ServerDraft? of(ChatStateEntity? state) => state == null
      ? null
      : ServerDraft(text: state.draft, updatedAt: state.draftUpdatedAt);

  final String? text;

  /// Null where the server did not say — `ChatDTO` does not document
  /// `draft_updated_at`, only `ChatStateDTO` does.
  final DateTime? updatedAt;

  /// The text as the server stores it: trimmed, and empty for none
  /// (`null` and `""` both clear a draft).
  String get normalized => text?.trim() ?? '';

  @override
  List<Object?> get props => [text, updatedAt];
}

enum DraftSide { local, server }

/// Which of two drafts for the same chat is the one that counts.
///
/// The rule is the newer `draft_updated_at` wins. Two refinements keep it
/// honest across devices whose clocks disagree:
///
/// * while the server still reports the version this device last agreed
///   with ([ChatDraft.syncedAt]), the server has not moved — so the local
///   copy is the same or newer, and wins without comparing clocks;
/// * where the server gives no timestamp, a local edit still waiting to be
///   written wins, and otherwise the server's copy does — it is what the
///   account holds now.
abstract final class ChatDraftMerge {
  static DraftSide winner({
    required ChatDraft? local,
    required ServerDraft? server,
  }) {
    if (local == null) return DraftSide.server;
    if (server == null) return DraftSide.local;
    if (local.text == server.normalized) return DraftSide.local;

    final serverAt = server.updatedAt;
    if (serverAt == null) {
      return local.pending ? DraftSide.local : DraftSide.server;
    }

    final agreedAt = local.syncedAt;
    if (agreedAt != null && serverAt.isAtSameMomentAs(agreedAt)) {
      return DraftSide.local;
    }

    return local.updatedAt.isAfter(serverAt)
        ? DraftSide.local
        : DraftSide.server;
  }

  /// The text that wins, or null when the winning side has no draft.
  static String? textOf({
    required ChatDraft? local,
    required ServerDraft? server,
  }) {
    final text = switch (winner(local: local, server: server)) {
      DraftSide.local => local?.text,
      DraftSide.server => server?.normalized,
    };
    return text == null || text.isEmpty ? null : text;
  }
}
