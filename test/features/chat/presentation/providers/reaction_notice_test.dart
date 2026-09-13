import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/features/chat/presentation/providers/reaction_notice_provider.dart';
import 'package:chatix/features/chat/presentation/utils/reaction_notice_text.dart';
import 'package:chatix/gen/l10n/app_localizations_en.dart';

/// An optimistic reaction that the server refused is taken back off the
/// message on its own; this is the channel that lets the screen say why.
void main() {
  ApiFailure api(String code, {Object? detail, int status = 400}) =>
      ApiFailure(code: code, message: code, detail: detail, status: status);

  group('reading a failure', () {
    test('REACTIONS_DISABLED — the chat turned them off under us', () {
      expect(
        ReactionNoticeController.reasonOf(api('REACTIONS_DISABLED')),
        ReactionNoticeReason.disabled,
      );
    });

    test('a white-list refusal and an unknown emoji read the same', () {
      expect(
        ReactionNoticeController.reasonOf(api('REACTION_NOT_ALLOWED')),
        ReactionNoticeReason.notAllowed,
      );
      expect(
        ReactionNoticeController.reasonOf(api('INVALID_REACTION')),
        ReactionNoticeReason.notAllowed,
      );
    });

    test('TOO_MANY_REACTIONS splits on the scope it carries', () {
      expect(
        ReactionNoticeController.reasonOf(
          api('TOO_MANY_REACTIONS', detail: {'limit': 3, 'scope': 'user'}),
        ),
        ReactionNoticeReason.tooManyForUser,
      );
      expect(
        ReactionNoticeController.reasonOf(
          api('TOO_MANY_REACTIONS', detail: {'limit': 20, 'scope': 'message'}),
        ),
        ReactionNoticeReason.tooManyForMessage,
      );
    });

    test('a scope-less TOO_MANY_REACTIONS falls back to the per-user cap', () {
      expect(
        ReactionNoticeController.reasonOf(api('TOO_MANY_REACTIONS')),
        ReactionNoticeReason.tooManyForUser,
      );
    });

    test('429 is a rate limit, not an error envelope (api-docs §2.2)', () {
      expect(
        ReactionNoticeController.reasonOf(const RateLimitFailure()),
        ReactionNoticeReason.tooFast,
      );
    });

    test('anything else is just a failure', () {
      expect(
        ReactionNoticeController.reasonOf(const NetworkFailure()),
        ReactionNoticeReason.failed,
      );
      expect(
        ReactionNoticeController.reasonOf(api('SOMETHING_NEW', status: 500)),
        ReactionNoticeReason.failed,
      );
    });
  });

  group('the channel', () {
    ProviderContainer boot() {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      return container;
    }

    test('starts quiet', () {
      expect(boot().read(reactionNoticeProvider), isNull);
    });

    test('reports what it read off the failure', () {
      final container = boot();

      container
          .read(reactionNoticeProvider.notifier)
          .report(const RateLimitFailure());

      expect(
        container.read(reactionNoticeProvider)?.reason,
        ReactionNoticeReason.tooFast,
      );
    });

    test('two identical failures in a row are two events', () {
      // The screen listens for a change; without the sequence the second
      // rollback would look like nothing happened.
      final container = boot();
      final notifier = container.read(reactionNoticeProvider.notifier);

      notifier.report(const NetworkFailure());
      final first = container.read(reactionNoticeProvider);

      notifier.report(const NetworkFailure());
      final second = container.read(reactionNoticeProvider);

      expect(second, isNot(first));
      expect(second!.sequence, first!.sequence + 1);
    });
  });

  group('what the reader is told', () {
    final l10n = AppLocalizationsEn();

    test('every reason has a line of its own', () {
      final lines = {
        for (final reason in ReactionNoticeReason.values)
          reason: reactionNoticeText(l10n, reason),
      };

      for (final entry in lines.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key.name);
      }
      expect(
        lines.values.toSet(),
        hasLength(ReactionNoticeReason.values.length),
      );
    });

    test('the two caps name their own limits', () {
      expect(
        reactionNoticeText(l10n, ReactionNoticeReason.tooManyForUser),
        contains('3'),
      );
      expect(
        reactionNoticeText(l10n, ReactionNoticeReason.tooManyForMessage),
        contains('20'),
      );
    });
  });
}
