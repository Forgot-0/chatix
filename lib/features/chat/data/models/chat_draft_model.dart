import 'dart:convert';

import 'package:chatix/features/chat/domain/entities/chat_draft.dart';

/// How a [ChatDraft] is written into the local drafts table — one string per
/// chat id, as the table has always held.
///
/// Before drafts were synced the string was the bare text. Those still read:
/// as a draft never written to the server, from an unknown time — so any
/// server copy that carries a time beats it, and one that does not loses to
/// it.
abstract final class ChatDraftCodec {
  static final DateTime _unknownTime = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  );

  static String encode(ChatDraft draft) => jsonEncode({
    'text': draft.text,
    'updated_at': draft.updatedAt.toUtc().toIso8601String(),
    if (draft.syncedAt != null)
      'synced_at': draft.syncedAt!.toUtc().toIso8601String(),
    'pending': draft.pending,
  });

  static ChatDraft? decode(String raw) {
    final structured = _decodeStructured(raw);
    if (structured != null) return structured;

    final legacy = raw.trim();
    if (legacy.isEmpty) return null;
    return ChatDraft(text: legacy, updatedAt: _unknownTime, pending: true);
  }

  static ChatDraft? _decodeStructured(String raw) {
    if (!raw.startsWith('{')) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, dynamic>) return null;

    final text = decoded['text'];
    final updatedAt = DateTime.tryParse('${decoded['updated_at']}');
    if (text is! String || updatedAt == null) return null;

    final synced = decoded['synced_at'];
    return ChatDraft(
      text: text,
      updatedAt: updatedAt,
      syncedAt: synced is String ? DateTime.tryParse(synced) : null,
      pending: decoded['pending'] == true,
    );
  }
}
