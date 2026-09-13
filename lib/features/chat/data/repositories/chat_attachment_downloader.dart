import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';

/// Pulls an attachment's bytes off the presigned link.
///
/// The counterpart of [ChatAttachmentUploader]: the link points straight at
/// the object store, not at the API, so this speaks to a client with no auth
/// header and no base URL (api-docs §5.5).
abstract class ChatAttachmentDownloader {
  /// Fetches [url] whole.
  ///
  /// A link that has outlived its 300 seconds comes back as a
  /// [ServerFailure] carrying the storage's status code, which is how the
  /// caller knows to ask the API for a fresh one rather than to give up.
  Future<Either<Failure, List<int>>> download({
    required String url,
    void Function(int received, int total)? onProgress,
    TransferCancellation? cancellation,
  });
}

/// Status codes a presigned GET answers with when the signature is no longer
/// good — the object may well still be there.
const Set<int> expiredLinkStatusCodes = {400, 401, 403};
