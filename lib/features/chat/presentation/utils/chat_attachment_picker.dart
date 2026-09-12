import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

enum _AttachmentSource { media, document }

/// Getting files out of the platform and into upload requests.
///
/// Media and documents are picked by different plugins and carry different
/// limits (api-docs §5.5), so the choice is made first and the picker follows
/// from it.
abstract final class ChatAttachmentPicker {
  /// Asks what kind of attachment, then asks the platform for it. Returns an
  /// empty list when either step is cancelled.
  static Future<List<AttachmentUploadRequestEntity>> pick(
    BuildContext context,
  ) async {
    final source = await showModalBottomSheet<_AttachmentSource>(
      context: context,
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext);

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(l10n.attachMedia),
                subtitle: Text(
                  l10n.attachMediaLimits(
                    ChatAttachmentLimits.maxMediaCount,
                    ChatAttachmentLimits.formatBytes(
                      ChatAttachmentLimits.maxMediaSizeBytes,
                    ),
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachmentSource.media),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.attachDocument),
                subtitle: Text(
                  l10n.attachDocumentLimits(
                    ChatAttachmentLimits.formatBytes(
                      ChatAttachmentLimits.maxFileSizeBytes,
                    ),
                  ),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_AttachmentSource.document),
              ),
            ],
          ),
        );
      },
    );

    return switch (source) {
      null => const [],
      _AttachmentSource.media => _pickMedia(),
      _AttachmentSource.document => _pickDocument(),
    };
  }

  static Future<List<AttachmentUploadRequestEntity>> _pickMedia() async {
    final files = await ImagePicker().pickMultiImage();

    final uploads = <AttachmentUploadRequestEntity>[];
    for (final file in files) {
      uploads.add(
        AttachmentUploadRequestEntity(
          filename: file.name,
          mimeType: file.mimeType ?? mimeFromName(file.name),
          fileSize: await file.length(),
          filePath: file.path,
        ),
      );
    }
    return uploads;
  }

  static Future<List<AttachmentUploadRequestEntity>> _pickDocument() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ChatAttachmentLimits.fileExtensions,
      allowMultiple: false,
      withData: kIsWeb,
      withReadStream: false,
    );

    final picked = result?.files.singleOrNull;
    if (picked == null) return const [];

    return [
      AttachmentUploadRequestEntity(
        filename: picked.name,
        mimeType: mimeFromName(picked.name),
        fileSize: picked.size,
        filePath: kIsWeb ? null : picked.path,
        bytes: picked.bytes,
      ),
    ];
  }

  /// The server checks the MIME type it is given, not the extension, so a
  /// wrong guess here is a rejected upload rather than a mislabelled file.
  static String mimeFromName(String name) {
    final ext = name.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'pdf':
        return 'application/pdf';
      case 'zip':
        return 'application/zip';
      case 'txt':
        return 'text/plain';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument'
            '.wordprocessingml.document';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument'
            '.spreadsheetml.sheet';
      default:
        return 'application/octet-stream';
    }
  }
}
