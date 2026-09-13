import 'dart:async';

/// A handle the UI can pull to stop a transfer that is already in flight.
///
/// Deliberately not a `dio` `CancelToken`: uploads and downloads are started
/// from use cases, and a domain-level call should not have to name the HTTP
/// client to offer a cancel button. The data layer adapts this to whatever
/// its client understands (see `ChatAttachmentUploaderImpl`).
///
/// One-shot: cancelling twice is the same as cancelling once, and a token
/// that has already fired stays fired, so a late listener still learns about
/// it through [whenCancelled].
class TransferCancellation {
  final Completer<void> _completer = Completer<void>();

  bool get isCancelled => _completer.isCompleted;

  /// Completes the moment [cancel] is called — never with an error, so it is
  /// safe to attach a bare `.then`.
  Future<void> get whenCancelled => _completer.future;

  void cancel() {
    if (_completer.isCompleted) return;
    _completer.complete();
  }
}
