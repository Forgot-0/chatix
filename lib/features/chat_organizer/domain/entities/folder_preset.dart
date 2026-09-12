import 'package:chatix/features/chat/domain/entities/chat_entity.dart';
import 'package:chatix/features/chat_organizer/domain/entities/folder_rule.dart';

/// A folder that ships with the app, written as rules like any other.
///
/// Presets are not a separate mechanism: each one is the [FolderRule] set a
/// user could have built by hand, which is why editing one turns it into an
/// ordinary custom folder rather than into a special case.
enum FolderPreset {
  unread('unread'),
  personal('personal'),
  groups('groups'),
  channels('channels'),
  noReplyFromMe('no_reply_from_me');

  const FolderPreset(this.wire);

  final String wire;

  String get folderId => 'preset.$wire';

  static FolderPreset? fromWire(String? value) {
    for (final preset in FolderPreset.values) {
      if (preset.wire == value) return preset;
    }
    return null;
  }

  List<FolderRule> get rules {
    switch (this) {
      case FolderPreset.unread:
        return const [UnreadRule()];
      case FolderPreset.personal:
        return const [
          ChatTypeRule({ChatType.direct}),
        ];
      case FolderPreset.groups:
        return const [
          ChatTypeRule({ChatType.group, ChatType.supergroup}),
        ];
      case FolderPreset.channels:
        return const [
          ChatTypeRule({ChatType.channel}),
        ];
      case FolderPreset.noReplyFromMe:
        return const [NoReplyFromMeRule()];
    }
  }

  /// The icon key the folder is drawn with; resolved to an [IconData] in the
  /// presentation layer, which is the only place that knows about Material.
  String get iconKey {
    switch (this) {
      case FolderPreset.unread:
        return 'unread';
      case FolderPreset.personal:
        return 'person';
      case FolderPreset.groups:
        return 'group';
      case FolderPreset.channels:
        return 'channel';
      case FolderPreset.noReplyFromMe:
        return 'reply';
    }
  }
}
