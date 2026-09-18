import 'package:flutter/material.dart';

import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';

/// What a conversation looks like before it has arrived.
///
/// A spinner in the middle of a chat says "something is happening"; this says
/// what is about to be there — a run of bubbles, alternating sides, in the
/// shapes messages actually come in. Because it occupies the same space the
/// feed will, the screen does not jump when the messages land, which is the
/// part a spinner cannot do however smooth it is.
///
/// Drawn newest-last like the feed itself, and never scrollable: it is a
/// placeholder, and a placeholder that can be scrolled invites the reader to
/// look for something that is not there.
class ChatFeedSkeleton extends StatelessWidget {
  const ChatFeedSkeleton({super.key});

  /// Width of each bubble as a fraction of the feed, and which side it is on.
  ///
  /// Hand-picked rather than random: a real conversation has a rhythm — a
  /// couple of short replies, one long one — and randomness produces
  /// something that reads as noise.
  static const List<({double width, bool isMine})> _bubbles = [
    (width: 0.52, isMine: false),
    (width: 0.34, isMine: true),
    (width: 0.68, isMine: false),
    (width: 0.44, isMine: true),
    (width: 0.30, isMine: true),
    (width: 0.58, isMine: false),
  ];

  @override
  Widget build(BuildContext context) {
    return AppSkeleton(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x3,
          vertical: AppSpacing.x4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final bubble in _bubbles)
              Align(
                alignment: bubble.isMine
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: FractionallySizedBox(
                  alignment: bubble.isMine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  widthFactor: bubble.width,
                  child: AppBone(
                    // Two lines of text plus the bubble's own padding: the
                    // height a short message actually takes.
                    height: 44,
                    radius: AppRadii.xl,
                    margin: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
