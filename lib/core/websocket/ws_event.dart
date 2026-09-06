import 'package:equatable/equatable.dart';

sealed class WSEvent extends Equatable {
  final String type;

  const WSEvent(this.type);

  @override
  List<Object?> get props => [type];
}

sealed class WSDomainEvent extends WSEvent {
  final String chatId;

  final String? eventName;

  final String? eventId;

  final DateTime? ts;

  const WSDomainEvent(
    super.type, {
    required this.chatId,
    this.eventName,
    this.eventId,
    this.ts,
  });

  @override
  List<Object?> get props => [type, chatId, eventName, eventId, ts];
}

sealed class WSMessageEvent extends WSDomainEvent {
  final String messageId;

  final int? seq;

  const WSMessageEvent(
    super.type, {
    required super.chatId,
    required this.messageId,
    required this.seq,
    super.eventName,
    super.eventId,
    super.ts,
  });

  @override
  List<Object?> get props => [...super.props, messageId, seq];
}

final class NewMessage extends WSMessageEvent {
  final int? senderId;

  final String? messageType;

  final Map<String, dynamic> message;

  const NewMessage({
    required super.chatId,
    required super.messageId,
    required super.seq,
    required this.message,
    this.senderId,
    this.messageType,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('new_message');

  @override
  List<Object?> get props => [...super.props, senderId, messageType, message];
}

final class MessageEdited extends WSMessageEvent {
  final int? modifiedBy;

  final Map<String, dynamic> message;

  const MessageEdited({
    required super.chatId,
    required super.messageId,
    required super.seq,
    required this.message,
    this.modifiedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_edited');

  @override
  List<Object?> get props => [...super.props, modifiedBy, message];
}

final class MessageDeleted extends WSMessageEvent {
  final int? deletedBy;

  const MessageDeleted({
    required super.chatId,
    required super.messageId,
    required super.seq,
    this.deletedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('message_deleted');

  @override
  List<Object?> get props => [...super.props, deletedBy];
}

final class MessagesRead extends WSDomainEvent {
  final int seq;

  final int readerId;

  const MessagesRead({
    required super.chatId,
    required this.seq,
    required this.readerId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('messages_read');

  @override
  List<Object?> get props => [...super.props, seq, readerId];
}

final class ReactionUpdated extends WSDomainEvent {
  final String messageId;

  final int? actorId;

  final String? action;

  final Map<String, dynamic> reaction;

  const ReactionUpdated({
    required super.chatId,
    required this.messageId,
    required this.reaction,
    this.actorId,
    this.action,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super(wireType);

  static const String wireType = 'reaction_update';

  static const String legacyWireType = 'chats.message.reaction_updated';

  @override
  List<Object?> get props => [...super.props, messageId, actorId, action, reaction];
}

final class MemberJoined extends WSDomainEvent {
  final int userId;

  final int? roleId;

  const MemberJoined({
    required super.chatId,
    required this.userId,
    this.roleId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_joined');

  @override
  List<Object?> get props => [...super.props, userId, roleId];
}

final class MemberLeft extends WSDomainEvent {
  final int userId;

  const MemberLeft({
    required super.chatId,
    required this.userId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_left');

  @override
  List<Object?> get props => [...super.props, userId];
}

final class MemberKick extends WSDomainEvent {
  final int targetUserId;

  final int? requesterId;

  const MemberKick({
    required super.chatId,
    required this.targetUserId,
    this.requesterId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_kick');

  @override
  List<Object?> get props => [...super.props, targetUserId, requesterId];
}

final class MemberBanned extends WSDomainEvent {
  final int targetUserId;

  final int? requesterId;

  final bool ban;

  const MemberBanned({
    required super.chatId,
    required this.targetUserId,
    required this.ban,
    this.requesterId,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('member_banned');

  @override
  List<Object?> get props => [...super.props, targetUserId, requesterId, ban];
}

final class ChatCreated extends WSDomainEvent {
  final int? createdBy;

  final String? name;

  final String? chatType;

  final List<int> memberIds;

  final int? memberCount;

  const ChatCreated({
    required super.chatId,
    this.createdBy,
    this.name,
    this.chatType,
    this.memberIds = const [],
    this.memberCount,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_created');

  @override
  List<Object?> get props => [
    ...super.props,
    createdBy,
    name,
    chatType,
    memberIds,
    memberCount,
  ];
}

final class ChatUpdated extends WSDomainEvent {
  final int? updatedBy;

  final String? name;
  final String? description;
  final bool? isPublic;
  final bool? adminOnly;
  final int? slowModeSeconds;
  final Map<String, bool>? permissions;

  final String? reactionsMode;

  final List<String>? allowedReactions;

  const ChatUpdated({
    required super.chatId,
    this.updatedBy,
    this.name,
    this.description,
    this.isPublic,
    this.adminOnly,
    this.slowModeSeconds,
    this.permissions,
    this.reactionsMode,
    this.allowedReactions,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_updated');

  @override
  List<Object?> get props => [
    ...super.props,
    updatedBy,
    name,
    description,
    isPublic,
    adminOnly,
    slowModeSeconds,
    permissions,
    reactionsMode,
    allowedReactions,
  ];
}

final class ChatDeleted extends WSDomainEvent {
  final int? deletedBy;

  const ChatDeleted({
    required super.chatId,
    this.deletedBy,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('chat_deleted');

  @override
  List<Object?> get props => [...super.props, deletedBy];
}

final class AttachmentSuccess extends WSDomainEvent {
  final int userId;

  final List<String> tokens;

  const AttachmentSuccess({
    required super.chatId,
    required this.userId,
    required this.tokens,
    super.eventName,
    super.eventId,
    super.ts,
  }) : super('attachment_success');

  @override
  List<Object?> get props => [...super.props, userId, tokens];
}

final class WsUnimplementedEvent extends WSEvent {
  final String? chatId;

  final Map<String, dynamic> payload;

  const WsUnimplementedEvent(super.type, {this.chatId, this.payload = const {}});

  static const Set<String> types = {
    'typing_start',
    'typing_stop',
    'call_started',
    'call_ended',
    'call_joined',
    'call_left',
  };

  @override
  List<Object?> get props => [type, chatId, payload];
}

final class WsReady extends WSEvent {
  final String connectionId;
  final String gatewayId;

  final int heartbeatInterval;

  final int heartbeatTimeout;

  final String? reconnectMode;

  final String? reconnectOp;

  const WsReady({
    required this.connectionId,
    required this.gatewayId,
    required this.heartbeatInterval,
    required this.heartbeatTimeout,
    this.reconnectMode,
    this.reconnectOp,
  }) : super('ws.ready');

  @override
  List<Object?> get props => [
    type,
    connectionId,
    gatewayId,
    heartbeatInterval,
    heartbeatTimeout,
    reconnectMode,
    reconnectOp,
  ];
}

final class WsSubscribed extends WSEvent {
  final String chatId;
  final int? lastSeq;
  final DateTime? ts;

  const WsSubscribed({required this.chatId, this.lastSeq, this.ts})
    : super('ws.subscribed');

  @override
  List<Object?> get props => [type, chatId, lastSeq, ts];
}

final class WsUnsubscribed extends WSEvent {
  final String chatId;
  final DateTime? ts;

  const WsUnsubscribed({required this.chatId, this.ts})
    : super('ws.unsubscribed');

  @override
  List<Object?> get props => [type, chatId, ts];
}

final class WsHistory extends WSEvent {
  final String chatId;

  final int afterSeq;

  final List<Map<String, dynamic>> messages;

  final bool hasMore;

  final int? nextLastSeq;

  final DateTime? ts;

  const WsHistory({
    required this.chatId,
    required this.afterSeq,
    required this.messages,
    required this.hasMore,
    this.nextLastSeq,
    this.ts,
  }) : super('ws.history');

  @override
  List<Object?> get props => [
    type,
    chatId,
    afterSeq,
    messages,
    hasMore,
    nextLastSeq,
    ts,
  ];
}

final class WsPong extends WSEvent {
  const WsPong() : super('ws.pong');
}

final class WsPing extends WSEvent {
  final String? connectionId;
  final DateTime? ts;

  const WsPing({this.connectionId, this.ts}) : super('ws.ping');

  @override
  List<Object?> get props => [type, connectionId, ts];
}

final class WsErrorBadCommand extends WSEvent {
  final String code;

  final String detail;

  final DateTime? ts;

  const WsErrorBadCommand({required this.code, required this.detail, this.ts})
    : super('ws.error');

  @override
  List<Object?> get props => [type, code, detail, ts];
}

final class WsErrorNotChatMember extends WSEvent {
  final String code;

  final DateTime? ts;

  final String? detail;

  const WsErrorNotChatMember({required this.code, this.ts, this.detail})
    : super('ws.error');

  @override
  List<Object?> get props => [type, code, ts, detail];
}

final class WsAuthInvalid extends WSEvent {
  final int? closeCode;
  final String? closeReason;

  const WsAuthInvalid({this.closeCode, this.closeReason})
    : super('client.auth_invalid');

  @override
  List<Object?> get props => [type, closeCode, closeReason];
}

final class WsUnknown extends WSEvent {
  final Map<String, dynamic> raw;

  const WsUnknown({required String type, required this.raw}) : super(type);

  @override
  List<Object?> get props => [type, raw];
}
