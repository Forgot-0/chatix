import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/network/transfer_cancellation.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/feedback/transfer_progress_ring.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/utils/attachment_actions.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a document looks like in a bubble: the kind of file it is, how big,
/// and what can be done with it.
///
/// A message carries at most one (api-docs §5.5), so this is a row rather
/// than a list. Until the gateway confirms the slot — `attachment_success`
/// over the socket, or `attachment_status` catching up — there is nothing to
/// open, so the glyph is a spinner and both actions are withheld.
///
/// Saving is the row's own business, because it is the only action with
/// something to show: the file comes down through the cache, the ring counts
/// it, and the button in the middle of the ring stops it.
class DocumentAttachmentRow extends ConsumerStatefulWidget {
  const DocumentAttachmentRow({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.foreground,
    this.onRetry,
  });

  final AttachmentEntity attachment;
  final String messageId;
  final Color foreground;

  /// Re-reads the message — all a failed slot can be offered (§5.5 carries
  /// no reason and nothing to re-run).
  final VoidCallback? onRetry;

  @override
  ConsumerState<DocumentAttachmentRow> createState() =>
      _DocumentAttachmentRowState();
}

class _DocumentAttachmentRowState extends ConsumerState<DocumentAttachmentRow> {
  TransferCancellation? _transfer;
  double? _progress;

  @override
  void dispose() {
    _transfer?.cancel();
    super.dispose();
  }

  bool get _isSaving => _transfer != null;

  Future<void> _save() async {
    if (_isSaving) return;

    final transfer = TransferCancellation();
    setState(() {
      _transfer = transfer;
      _progress = null;
    });

    await AttachmentActions.save(
      context,
      ref,
      attachment: widget.attachment,
      messageId: widget.messageId,
      cancellation: transfer,
      onProgress: (received, total) {
        if (!mounted) return;
        setState(() => _progress = total > 0 ? received / total : null);
      },
    );

    if (!mounted) return;
    setState(() {
      _transfer = null;
      _progress = null;
    });
  }

  void _cancel() {
    _transfer?.cancel();
    setState(() {
      _transfer = null;
      _progress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);

    final attachment = widget.attachment;

    // Watched for its side effect: with auto-download on for files this puts
    // the document on disk before it is tapped, and with it off — the
    // default, a document being the most expensive thing in a chat — it does
    // nothing. Opening one fetches it either way.
    ref.watch(
      autoAttachmentFileProvider(
        attachmentFileKey(attachment, messageId: widget.messageId),
      ),
    );

    final confirmed = ref.watch(confirmedAttachmentTokensProvider);
    final isReady =
        attachment.attachmentStatus == AttachmentStatus.success ||
        confirmed.contains(attachment.id);
    final hasFailed = attachment.attachmentStatus == AttachmentStatus.error;

    final kind = DocumentKind.of(attachment.originalFilename);

    final Widget leading;
    if (hasFailed) {
      leading = TransferProgressRing(
        state: TransferRingState.failed,
        progress: 1,
        onPressed: widget.onRetry,
        size: 40,
        semanticLabel: l10n.retry,
      );
    } else if (!isReady) {
      leading = TransferProgressRing(
        state: TransferRingState.waiting,
        size: 40,
        semanticLabel: l10n.attachmentProcessing,
      );
    } else if (_isSaving) {
      leading = TransferProgressRing(
        state: TransferRingState.running,
        progress: _progress,
        onPressed: _cancel,
        size: 40,
        semanticLabel: l10n.cancel,
      );
    } else {
      leading = _KindBadge(kind: kind);
    }

    final String subtitle;
    if (hasFailed) {
      subtitle = l10n.attachmentFailed;
    } else if (!isReady) {
      subtitle = l10n.attachmentProcessing;
    } else {
      subtitle =
          '${kind.label} · '
          '${ChatAttachmentLimits.formatBytes(attachment.size)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: AppSpacing.x3),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  attachment.originalFilename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: widget.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: hasFailed
                        ? chatix.danger
                        : widget.foreground.withValues(alpha: 0.7),
                  ),
                ),
                if (isReady && !hasFailed)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.x1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Action(
                          label: l10n.attachmentOpen,
                          icon: Icons.open_in_new_rounded,
                          color: widget.foreground,
                          onPressed: () => AttachmentActions.open(
                            context,
                            ref,
                            attachment: attachment,
                            messageId: widget.messageId,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.x2),
                        _Action(
                          label: l10n.save,
                          icon: Icons.download_rounded,
                          color: widget.foreground,
                          onPressed: _isSaving ? null : _save,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});

  final DocumentKind kind;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: kind.color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      alignment: Alignment.center,
      child: Icon(kind.icon, size: 20, color: kind.color),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// What kind of document a filename says it is.
///
/// Keyed off the extension rather than the MIME type: both are in the DTO,
/// but the extension is what the name in the bubble shows, and the two can
/// disagree (`text/plain` for a `.csv`, say). Only the buckets api-docs §5.5
/// accepts get their own glyph; anything else is a generic file.
enum DocumentKind {
  pdf(Icons.picture_as_pdf_rounded, Color(0xFFE5484D), 'PDF'),
  archive(Icons.folder_zip_rounded, Color(0xFFF5A524), 'ZIP'),
  document(Icons.description_rounded, Color(0xFF2563C9), 'DOC'),
  spreadsheet(Icons.table_chart_rounded, Color(0xFF22A06B), 'XLS'),
  text(Icons.article_rounded, Color(0xFF6B6359), 'TXT'),
  other(Icons.insert_drive_file_rounded, Color(0xFF6B6359), 'FILE');

  const DocumentKind(this.icon, this.color, this.label);

  final IconData icon;
  final Color color;

  /// The short badge text — also what the row shows beside the size.
  final String label;

  static DocumentKind of(String filename) {
    final dot = filename.lastIndexOf('.');
    if (dot <= 0 || dot == filename.length - 1) return DocumentKind.other;

    return switch (filename.substring(dot + 1).toLowerCase()) {
      'pdf' => DocumentKind.pdf,
      'zip' => DocumentKind.archive,
      'doc' || 'docx' => DocumentKind.document,
      'xls' || 'xlsx' || 'csv' => DocumentKind.spreadsheet,
      'txt' => DocumentKind.text,
      _ => DocumentKind.other,
    };
  }
}
