import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import 'package:chatix/core/error/failures.dart';
import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_providers.dart';

/// Where one document stands on this device.
enum AttachmentDownloadPhase {
  /// Not known yet: the cache is being looked in, or the reader's
  /// auto-download setting is already fetching it (with no figure to show).
  unknown,

  /// Not on this device. A tap downloads it.
  remote,

  /// Coming down now; [AttachmentDownloadState.progress] says how far.
  downloading,

  /// On this device. A tap opens it.
  local,
}

@immutable
class AttachmentDownloadState {
  const AttachmentDownloadState._(
    this.phase, {
    this.file,
    this.received = 0,
    this.total = 0,
  });

  const AttachmentDownloadState.unknown()
    : this._(AttachmentDownloadPhase.unknown);

  const AttachmentDownloadState.remote()
    : this._(AttachmentDownloadPhase.remote);

  const AttachmentDownloadState.downloading({int received = 0, int total = 0})
    : this._(
        AttachmentDownloadPhase.downloading,
        received: received,
        total: total,
      );

  const AttachmentDownloadState.local(File file)
    : this._(AttachmentDownloadPhase.local, file: file);

  final AttachmentDownloadPhase phase;

  /// The cached copy, once [phase] is [AttachmentDownloadPhase.local].
  final File? file;

  /// Bytes so far and in all, while downloading. [total] is 0 when the
  /// server did not say.
  final int received;
  final int total;

  /// 0..1, or null while the share is unknown.
  double? get progress =>
      total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;

  @override
  bool operator ==(Object other) =>
      other is AttachmentDownloadState &&
      other.phase == phase &&
      other.file?.path == file?.path &&
      other.received == received &&
      other.total == total;

  @override
  int get hashCode => Object.hash(phase, file?.path, received, total);
}

/// One document's download: what the bubble's round button shows, and what
/// "Save", "Share" and "Show in folder" wait on.
///
/// Shared rather than kept in the row, so that picking "Save" from the menu
/// fills the same ring a tap on the row would — and a document downloaded
/// once, by either, is opened by the next tap rather than fetched again.
/// The bytes go to the attachment cache under their `s3_key` (api-docs
/// §5.5), the same place every other attachment lives.
class AttachmentDownloadController extends Notifier<AttachmentDownloadState> {
  AttachmentDownloadController(this._key);

  final AttachmentFileKey _key;

  TransferCancellation? _transfer;
  Future<Either<Failure, File>>? _pending;

  @override
  AttachmentDownloadState build() {
    // The reader's auto-download setting decides whether the file comes
    // down by itself; with it off this is a look in the cache, nothing more.
    ref.listen(autoAttachmentFileProvider(_key), (_, next) => _absorb(next));
    ref.onDispose(() => _transfer?.cancel());

    return _fromAuto(ref.read(autoAttachmentFileProvider(_key)));
  }

  /// The file, downloading it first if this device does not have it yet.
  ///
  /// A second call while the first is still running joins it rather than
  /// starting another download.
  Future<Either<Failure, File>> fetch() {
    final file = state.file;
    if (file != null) return Future.value(Right(file));
    return _pending ??= _download();
  }

  /// Stops a download under way. Nothing is kept, and the next tap starts
  /// over.
  void cancel() {
    final transfer = _transfer;
    if (transfer == null) return;

    transfer.cancel();
    _transfer = null;
    _pending = null;
    state = const AttachmentDownloadState.remote();
  }

  Future<Either<Failure, File>> _download() async {
    final transfer = TransferCancellation();
    _transfer = transfer;

    // Held alive for the length of the download: a row scrolled away, or
    // the menu that asked for it closing, is not a reason to drop it.
    final link = ref.keepAlive();
    final useCase = ref.read(getAttachmentFileUseCaseProvider);
    state = const AttachmentDownloadState.downloading();

    bool current() => ref.mounted && identical(_transfer, transfer);

    try {
      final result = await useCase.execute(
        chatId: _key.chatId,
        messageId: _key.messageId,
        attachment: _key.attachment,
        cancellation: transfer,
        onProgress: (received, total) {
          if (!current()) return;
          state = AttachmentDownloadState.downloading(
            received: received,
            total: total,
          );
        },
      );

      if (current()) {
        state = result.fold(
          (_) => const AttachmentDownloadState.remote(),
          AttachmentDownloadState.local,
        );
      }
      return result;
    } finally {
      if (identical(_transfer, transfer)) {
        _transfer = null;
        _pending = null;
      }
      link.close();
    }
  }

  void _absorb(AsyncValue<File?> next) {
    // A download of our own says more than the setting does.
    if (_transfer != null) return;

    final resolved = _fromAuto(next);
    if (resolved.phase == AttachmentDownloadPhase.unknown) return;
    if (state.phase == AttachmentDownloadPhase.local &&
        resolved.phase == AttachmentDownloadPhase.remote) {
      return;
    }
    state = resolved;
  }

  static AttachmentDownloadState _fromAuto(AsyncValue<File?> value) =>
      switch (value) {
        AsyncData(value: final File file) => AttachmentDownloadState.local(
          file,
        ),
        AsyncData() => const AttachmentDownloadState.remote(),
        // An auto-download that failed leaves the tap to try again.
        AsyncError() => const AttachmentDownloadState.remote(),
        _ => const AttachmentDownloadState.unknown(),
      };
}

final attachmentDownloadProvider = NotifierProvider.autoDispose
    .family<
      AttachmentDownloadController,
      AttachmentDownloadState,
      AttachmentFileKey
    >(AttachmentDownloadController.new);

/// Where each document saved this session ended up, by `s3_key`, so that
/// "Show in folder" opens the copy already made instead of making another.
class SavedAttachmentPaths extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => const {};

  void remember(String s3Key, String path) => state = {...state, s3Key: path};

  /// The saved copy, if there is one and it is still where it was put.
  File? find(String s3Key) {
    final path = state[s3Key];
    if (path == null) return null;

    final file = File(path);
    return file.existsSync() ? file : null;
  }
}

final savedAttachmentPathsProvider =
    NotifierProvider<SavedAttachmentPaths, Map<String, String>>(
      SavedAttachmentPaths.new,
    );
