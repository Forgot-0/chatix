import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where the chat list was scrolled to, kept outside the widget tree.
///
/// A tab switch alone would not need this — the shell's `IndexedStack` keeps
/// the branch mounted, scroll offset and all. The rotation does: crossing the
/// two-pane breakpoint moves the list from the `/chats` page into the shell's
/// left pane, and those are different routes with different
/// `PageStorageBucket`s, so nothing the framework stores travels between them.
/// The offset lives here instead, and both mount points read it on the way in
/// and write it on the way out.
class ChatListScrollOffset extends Notifier<double> {
  @override
  double build() => 0;

  void save(double offset) {
    if (offset < 0 || offset == state) return;
    state = offset;
  }
}

final chatListScrollOffsetProvider =
    NotifierProvider<ChatListScrollOffset, double>(ChatListScrollOffset.new);
