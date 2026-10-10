import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/features/chat/domain/entities/chat_draft.dart';
import 'package:chatix/features/chat/domain/entities/chat_entity.dart';

/// Two copies of one chat's draft — this device's and the server's — and
/// the rule that picks one: the newer `draft_updated_at` wins.
void main() {
  final t0 = DateTime.utc(2026, 10, 11, 9);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  ChatDraft local(
    String text,
    int seconds, {
    int? synced,
    bool pending = true,
  }) => ChatDraft(
    text: text,
    updatedAt: at(seconds),
    syncedAt: synced == null ? null : at(synced),
    pending: pending,
  );

  ServerDraft server(String? text, [int? seconds]) =>
      ServerDraft(text: text, updatedAt: seconds == null ? null : at(seconds));

  DraftSide winner(ChatDraft? l, ServerDraft? s) =>
      ChatDraftMerge.winner(local: l, server: s);

  group('by time', () {
    test('a newer local draft beats an older server one', () {
      expect(winner(local('mine', 20), server('theirs', 10)), DraftSide.local);
    });

    test('a newer server draft beats an older local one', () {
      expect(winner(local('mine', 10), server('theirs', 20)), DraftSide.server);
    });

    test('a draft cleared on another device later clears it here', () {
      final l = local('mine', 10, pending: false, synced: 5);
      final s = server(null, 20);

      expect(winner(l, s), DraftSide.server);
      expect(ChatDraftMerge.textOf(local: l, server: s), isNull);
    });

    test('a draft cleared here later keeps an older server one away', () {
      final l = local('', 30);
      final s = server('stale', 20);

      expect(winner(l, s), DraftSide.local);
      expect(ChatDraftMerge.textOf(local: l, server: s), isNull);
    });

    test('a tie goes to the server, which is what every device sees', () {
      expect(winner(local('mine', 10), server('theirs', 10)), DraftSide.server);
    });
  });

  group('one side missing', () {
    test('nothing here: the server\'s copy', () {
      expect(winner(null, server('theirs', 10)), DraftSide.server);
      expect(
        ChatDraftMerge.textOf(local: null, server: server(' theirs ', 10)),
        'theirs',
      );
    });

    test('a response without per-user state says nothing either way', () {
      expect(winner(local('mine', 10), null), DraftSide.local);
      expect(ServerDraft.of(null), isNull);
    });

    test('neither side has a draft', () {
      expect(ChatDraftMerge.textOf(local: null, server: null), isNull);
      expect(ChatDraftMerge.textOf(local: null, server: server(null)), isNull);
    });
  });

  group('when clocks cannot be compared', () {
    test('the same text is no conflict at all', () {
      expect(winner(local('same', 99), server(' same ', 1)), DraftSide.local);
    });

    test('a server copy without a time loses to a local edit still '
        'waiting to be written…', () {
      expect(winner(local('mine', 10), server('theirs')), DraftSide.local);
    });

    test('…and wins over one that was already written', () {
      final l = local('mine', 10, pending: false, synced: 10);

      expect(winner(l, server('theirs')), DraftSide.server);
    });

    test('while the server still holds the version agreed on, the local '
        'edit is newer whatever this clock says', () {
      // Synced at the server's 12:00:50; this device's clock runs a minute
      // slow, so the edit typed afterwards is stamped "12:00:30".
      final l = local('typed after', 30, synced: 50);

      expect(winner(l, server('agreed', 50)), DraftSide.local);
    });

    test('once the server has moved on, time decides again', () {
      final l = local('typed after', 30, synced: 50);

      expect(winner(l, server('from elsewhere', 60)), DraftSide.server);
    });
  });

  test('ServerDraft reads a row\'s state block', () {
    final s = ServerDraft.of(
      ChatStateEntity(draft: 'hello', draftUpdatedAt: at(5)),
    );

    expect(s, server('hello', 5));
    expect(s!.normalized, 'hello');
  });
}
