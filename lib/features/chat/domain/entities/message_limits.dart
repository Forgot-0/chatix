/// What the server will accept in a message body.
///
/// `content` is capped at 4096 characters and anything longer comes back
/// `400 MESSAGE_TOO_LONG` (api-docs §5.4). The composer counts against this
/// itself so the refusal happens under the reader's thumb rather than after
/// a round trip.
abstract final class MessageLimits {
  /// `SendMessageRequest.content` ≤ 4096, and the same for an edit.
  static const int maxContentLength = 4096;

  /// Where the counter starts showing.
  ///
  /// Far enough from the cap that it is a warning rather than an alarm, and
  /// late enough that an ordinary message never has a number hanging off it.
  static const int counterVisibleFrom = 3800;

  /// Whether the counter should be on screen at this length.
  static bool showsCounter(int length) => length >= counterVisibleFrom;

  /// How close to the cap this length is, as 0 at the threshold and 1 at the
  /// limit. Drives the colour the counter takes on the way.
  static double pressure(int length) {
    if (length <= counterVisibleFrom) return 0;
    if (length >= maxContentLength) return 1;

    return (length - counterVisibleFrom) /
        (maxContentLength - counterVisibleFrom);
  }

  /// What is left, floored at zero.
  static int remaining(int length) {
    final left = maxContentLength - length;
    return left < 0 ? 0 : left;
  }

  static bool isOverLimit(int length) => length > maxContentLength;
}
