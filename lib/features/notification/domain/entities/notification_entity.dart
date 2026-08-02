import 'package:equatable/equatable.dart';

/// `NotificationDTO.type` (api-docs §8.2).
///
/// The three documented values are `system` / `project` / `chat`. Unlike most
/// enums in this app there is **no documented default** for this field, so an
/// unknown wire value degrades to [NotificationType.system] rather than
/// throwing: a notification we can't classify is still a notification the
/// user should see in the list, and the backend adding a fourth type later
/// must not blank out the whole page with a parse error.
enum NotificationType {
  system,
  project,
  chat;

  String get wire => name;

  static NotificationType fromWire(String? value) {
    return NotificationType.values.firstWhere(
      (t) => t.name == value,
      orElse: () => NotificationType.system,
    );
  }
}

/// `NotificationDTO` (api-docs §8.2).
///
/// ### About [payload]
///
/// ⚠️ `payload` is `Record<string, unknown>` on the wire — its shape depends
/// on [type] and is **not typed on the backend at all** (api-docs §8.2 says
/// so explicitly). A chat notification *may* carry `chat_id`/`message_id`, a
/// project one *may* carry `project_id`, but nothing guarantees any key is
/// present, of the expected runtime type, or non-null.
///
/// It is therefore kept as a raw `Map<String, dynamic>` and never destructured
/// into typed fields at this layer. Every read goes through the defensive
/// accessors below ([chatId], [projectId], …) which return `null` instead of
/// throwing on a missing/mistyped key. Do not add `required` typed payload
/// fields to this entity — a single unexpected payload from the server would
/// then break parsing for the entire page.
class NotificationEntity extends Equatable {
  final int id;
  final int userId;
  final NotificationType type;
  final String title;

  /// Nullable on the wire (api-docs §8.2) — a title-only notification is
  /// legitimate, so the UI must tolerate a missing body.
  final String? message;

  /// Untyped by design — see the class doc. Always non-null (defaults to an
  /// empty map when the key is absent) so call sites never null-check it.
  final Map<String, dynamic> payload;

  final bool isRead;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationEntity({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.payload,
    required this.isRead,
    required this.createdAt,
    required this.updatedAt,
  });

  NotificationEntity copyWith({bool? isRead}) {
    return NotificationEntity(
      id: id,
      userId: userId,
      type: type,
      title: title,
      message: message,
      payload: payload,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  // ──────────────────── Defensive payload accessors ────────────────────
  //
  // These exist so navigation code can ask "is there a chat to open?"
  // without every call site repeating the same null/type dance. They all
  // fail soft: a missing key, a null, or a value of the wrong runtime type
  // yields `null`, never an exception.

  /// A `chat_id` from [payload], if one is present and looks like a chat id.
  ///
  /// Chat ids are **UUID strings** (api-docs §1.8), so anything is accepted
  /// that stringifies to a non-empty value — the server has been known to
  /// serialize ids inconsistently across modules, and this is a best-effort
  /// deep link, not a validated request parameter.
  String? get chatId => _stringValue('chat_id');

  /// A `message_id` (UUID string, api-docs §1.8) from [payload], if present.
  /// Used to scroll to a specific message once the chat is open.
  String? get messageId => _stringValue('message_id');

  /// A `project_id` from [payload], if present. Project ids are **integers**
  /// (api-docs §1.8), but JSON may deliver one as a number *or* as a string,
  /// so both are accepted.
  int? get projectId => _intValue('project_id');

  String? _stringValue(String key) {
    final value = payload[key];
    if (value == null) return null;
    final asString = value.toString().trim();
    return asString.isEmpty ? null : asString;
  }

  int? _intValue(String key) {
    final value = payload[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    type,
    title,
    message,
    payload,
    isRead,
    createdAt,
    updatedAt,
  ];
}
