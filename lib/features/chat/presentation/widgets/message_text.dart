import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:chatix/features/chat/presentation/utils/message_linkifier.dart';

/// The body of a message, drawn as text and nothing else.
///
/// Content is stored unescaped (api-docs §5.4), so it is never handed to
/// anything that interprets markup. [MessageLinkifier] finds the stretches
/// worth tapping and this paints them; every other character is drawn exactly
/// as it arrived.
class MessageText extends StatefulWidget {
  const MessageText({
    super.key,
    required this.content,
    required this.style,
    required this.linkColor,
    this.isKnownMention,
    this.onOpenLink,
  });

  final String content;

  final TextStyle style;

  /// Links are tinted and underlined rather than given their own colour
  /// scheme: on an outgoing bubble the ground is already the accent.
  final Color linkColor;

  final bool Function(String handle)? isKnownMention;

  final void Function(LinkSpan link)? onOpenLink;

  @override
  State<MessageText> createState() => _MessageTextState();
}

class _MessageTextState extends State<MessageText> {
  List<MessageSpan> _spans = const [];

  /// One per link span, built when the spans are and disposed with them.
  ///
  /// Never rebuilt during `build`: a recognizer disposed mid-frame is one the
  /// mounted paragraph may still be hit-testing. Each reads `widget` when it
  /// fires, so a caller handing in a fresh closure every frame still gets the
  /// current one.
  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(covariant MessageText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An edit replaces the content outright. The resolver can also start
    // answering differently once the roster loads, but it arrives as a fresh
    // closure on every rebuild, so that check is narrowed to messages with an
    // `@` in them — the only ones whose spans it could change.
    final mentionsMayHaveMoved =
        widget.content.contains('@') &&
        widget.isKnownMention != oldWidget.isKnownMention;

    if (widget.content != oldWidget.content || mentionsMayHaveMoved) {
      _parse();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _parse() {
    _disposeRecognizers();
    _spans = MessageLinkifier.parse(
      widget.content,
      isKnownMention: widget.isKnownMention,
    );

    for (var i = 0; i < _spans.length; i++) {
      final span = _spans[i];
      if (span is! LinkSpan) continue;
      _recognizers[i] = TapGestureRecognizer()
        ..onTap = () => widget.onOpenLink?.call(span);
    }
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    // Nothing to tap means nothing to style differently, and the whole
    // message is one plain span.
    if (widget.onOpenLink == null || _recognizers.isEmpty) {
      return Text(widget.content, style: widget.style);
    }

    final linkStyle = widget.style.copyWith(
      color: widget.linkColor,
      decoration: TextDecoration.underline,
      decorationColor: widget.linkColor.withValues(alpha: 0.5),
    );

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (var i = 0; i < _spans.length; i++)
            if (_spans[i] case final LinkSpan link)
              TextSpan(
                text: link.text,
                style: linkStyle,
                recognizer: _recognizers[i],
                semanticsLabel: link.text,
              )
            else
              TextSpan(text: _spans[i].text),
        ],
      ),
    );
  }
}
