import 'package:dio/dio.dart';

/// A handle the caller can pull to drop a request it no longer wants.
///
/// Wraps dio's `CancelToken` so the layers above the data sources can cancel
/// work without importing dio: a use case takes one of these, a data source
/// unwraps [dioToken] and hands it to the client. A cancelled request comes
/// back as [CancelledFailure], which callers are meant to ignore rather than
/// show — nobody wants an error about the search they themselves replaced.
class RequestCancellation {
  RequestCancellation();

  final CancelToken _token = CancelToken();

  bool get isCancelled => _token.isCancelled;

  /// The token the data layer passes to dio. Nothing above the data layer
  /// should reach for this.
  CancelToken get dioToken => _token;

  /// Drops the request. Calling it twice is harmless, which matters because
  /// the usual caller is a `ref.onDispose` that may run after the request has
  /// already finished.
  void cancel([String? reason]) {
    if (_token.isCancelled) return;
    _token.cancel(reason ?? 'superseded');
  }
}
