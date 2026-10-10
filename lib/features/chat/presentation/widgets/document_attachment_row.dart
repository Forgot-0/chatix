import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/localization/file_size_format.dart';
import 'package:chatix/core/storage/file_revealer.dart';
import 'package:chatix/core/storage/file_sharer.dart';
import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/core/ui/typography/middle_ellipsis_text.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_download_provider.dart';
import 'package:chatix/features/chat/presentation/providers/attachment_file_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_socket_provider.dart';
import 'package:chatix/features/chat/presentation/utils/attachment_actions.dart';
import 'package:chatix/features/chat/presentation/widgets/message_meta.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What a document looks like in a bubble: a round button that says what a
/// tap will do, the file's name, and how big it is.
///
/// One tap does the one obvious thing — downloads the file, and once it is
/// here, opens it; tapped while it comes down, it stops. The ring around the
/// button counts the download. Saving, sharing and finding the saved copy
/// are in the message's own menu, where the rest of what can be done to a
/// message lives, rather than as a row of buttons in every bubble.
///
/// A message carries at most one (api-docs §5.5). Until the gateway
/// confirms the slot — `attachment_success` over the socket, or
/// `attachment_status` catching up — there is nothing to download, and the
/// button only spins.
class DocumentAttachmentRow extends ConsumerWidget {
  const DocumentAttachmentRow({
    super.key,
    required this.attachment,
    required this.messageId,
    required this.foreground,
    this.muted,
    this.isMine = false,
    this.onRetry,
    this.anchorsMeta = false,
    this.showMenu = false,
  });

  final AttachmentEntity attachment;
  final String messageId;
  final Color foreground;

  /// The size line's colour; [foreground] at a readable strength when not
  /// given.
  final Color? muted;

  /// On your own bubble the button is a pale disc on the accent; on anyone
  /// else's it is the file kind's colour.
  final bool isMine;

  /// Re-reads the message — all a failed slot can be offered (§5.5 carries
  /// no reason and nothing to re-run).
  final VoidCallback? onRetry;

  /// Whether the bubble's time shares the size line, when this row ends
  /// the bubble.
  final bool anchorsMeta;

  /// Whether the row carries its own menu of save, share and show in
  /// folder. A bubble has the message's menu for that; a list of a chat's
  /// files has nothing else.
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final chatix = ChatixTheme.of(context);
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    final key = attachmentFileKey(attachment, messageId: messageId);
    final download = ref.watch(attachmentDownloadProvider(key));

    final confirmed = ref.watch(confirmedAttachmentTokensProvider);
    final hasFailed = attachment.attachmentStatus == AttachmentStatus.error;
    final isReady =
        !hasFailed &&
        (attachment.attachmentStatus == AttachmentStatus.success ||
            confirmed.contains(attachment.id));

    final kind = DocumentKind.of(attachment.originalFilename);
    final muted = this.muted ?? foreground.withValues(alpha: 0.72);

    final _ButtonState button;
    if (hasFailed) {
      button = _ButtonState.failed;
    } else if (!isReady) {
      button = _ButtonState.processing;
    } else {
      button = switch (download.phase) {
        AttachmentDownloadPhase.downloading => _ButtonState.downloading,
        AttachmentDownloadPhase.local => _ButtonState.local,
        AttachmentDownloadPhase.remote ||
        AttachmentDownloadPhase.unknown => _ButtonState.remote,
      };
    }

    final size = formatFileSize(attachment.size, l10n, locale: locale);
    final String subtitle;
    if (hasFailed) {
      subtitle = l10n.attachmentFailed;
    } else if (!isReady) {
      subtitle = l10n.attachmentProcessing;
    } else if (button == _ButtonState.downloading && download.total > 0) {
      subtitle = l10n.attachmentDownloadProgress(
        formatFileSize(download.received, l10n, locale: locale),
        size,
      );
    } else {
      subtitle = '$size · ${kind.label}';
    }

    final VoidCallback? onTap = switch (button) {
      _ButtonState.failed => onRetry,
      _ButtonState.processing => null,
      _ButtonState.remote => () => AttachmentActions.download(
        context,
        ref,
        attachment: attachment,
        messageId: messageId,
      ),
      _ButtonState.downloading =>
        ref.read(attachmentDownloadProvider(key).notifier).cancel,
      _ButtonState.local => () => AttachmentActions.open(
        context,
        ref,
        attachment: attachment,
        messageId: messageId,
        local: download.file,
      ),
    };

    final actionLabel = switch (button) {
      _ButtonState.failed => l10n.retry,
      _ButtonState.processing => null,
      _ButtonState.remote => l10n.attachmentDownload,
      _ButtonState.downloading => l10n.cancel,
      _ButtonState.local => l10n.attachmentOpen,
    };

    final subtitleStyle = theme.textTheme.labelSmall?.copyWith(
      color: hasFailed ? chatix.danger : muted,
      fontFeatures: AppTypography.tabularFigures,
    );
    final sizeLine = Text(subtitle, style: subtitleStyle);

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _DocumentButton(
          state: button,
          kind: kind,
          progress: download.progress,
          isMine: isMine,
          foreground: foreground,
        ),
        const SizedBox(width: AppSpacing.x3),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              MiddleEllipsisText(
                attachment.originalFilename,
                maxLines: ChatLayout.documentNameMaxLines,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ChatLayout.attachmentRowPaddingY),
              if (anchorsMeta) MessageMetaAnchor(child: sizeLine) else sizeLine,
            ],
          ),
        ),
        if (showMenu && isReady) ...[
          const SizedBox(width: AppSpacing.x1),
          _DocumentMenu(attachment: attachment, messageId: messageId),
        ],
      ],
    );

    return Semantics(
      button: onTap != null,
      onTapHint: actionLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: ChatLayout.attachmentRowPaddingY,
          ),
          child: row,
        ),
      ),
    );
  }
}

enum _ButtonState { failed, processing, remote, downloading, local }

/// The round button a document leads with.
///
/// Its glyph is what a tap will do: an arrow to download, a cross to stop,
/// the kind of file once it is here to open. While it comes down a ring
/// around the inside of the disc fills.
class _DocumentButton extends StatelessWidget {
  const _DocumentButton({
    required this.state,
    required this.kind,
    required this.progress,
    required this.isMine,
    required this.foreground,
  });

  final _ButtonState state;
  final DocumentKind kind;
  final double? progress;
  final bool isMine;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final chatix = ChatixTheme.of(context);

    // On your own bubble the disc is a lighter wash of the bubble's own
    // foreground, so it reads as part of the accent rather than a sticker
    // on it; elsewhere it is the kind's colour, with a white glyph wherever
    // white reads on it.
    final Color fill;
    final Color glyph;
    if (state == _ButtonState.failed) {
      fill = chatix.danger;
      glyph = AppContrast.iconOn(chatix.danger);
    } else if (isMine) {
      fill = foreground.withValues(alpha: 0.22);
      glyph = foreground;
    } else {
      fill = kind.color;
      glyph = AppContrast.iconOn(kind.color);
    }

    final icon = switch (state) {
      _ButtonState.failed => Icons.refresh_rounded,
      _ButtonState.processing => kind.icon,
      _ButtonState.remote => Icons.arrow_downward_rounded,
      _ButtonState.downloading => Icons.close_rounded,
      _ButtonState.local => kind.icon,
    };

    final ring = switch (state) {
      _ButtonState.downloading => _Ring(value: progress, color: glyph),
      // Nothing to count yet: the gateway is still checking the upload.
      _ButtonState.processing => _Ring(value: null, color: glyph),
      _ => null,
    };

    return SizedBox.square(
      dimension: ChatLayout.documentButtonSize,
      child: DecoratedBox(
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ?ring,
            AnimatedSwitcher(
              duration: AppMotion.fast,
              child: Icon(
                icon,
                key: ValueKey(icon),
                size: ChatLayout.documentGlyphSize,
                color: glyph,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.color});

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const inset = ChatLayout.documentRingStroke * 1.5;

    return Padding(
      padding: const EdgeInsets.all(inset),
      child: SizedBox.expand(
        child: CircularProgressIndicator(
          value: value,
          strokeWidth: ChatLayout.documentRingStroke,
          strokeCap: StrokeCap.round,
          color: color,
          backgroundColor: color.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}

/// Save, share and show in folder, for a row that is not in a bubble and so
/// has no message menu to put them in.
class _DocumentMenu extends ConsumerWidget {
  const _DocumentMenu({required this.attachment, required this.messageId});

  final AttachmentEntity attachment;
  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final canShare = ref.watch(fileSharerProvider).isSupported;
    final canReveal = ref.watch(fileRevealerProvider).isSupported;

    return PopupMenuButton<DocumentAction>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (action) => DocumentAction.run(
        action,
        context,
        ref,
        attachment: attachment,
        messageId: messageId,
      ),
      itemBuilder: (context) => [
        for (final action in DocumentAction.values)
          if (action != DocumentAction.share || canShare)
            if (action != DocumentAction.showInFolder || canReveal)
              PopupMenuItem(
                value: action,
                child: ListTile(
                  leading: Icon(action.icon),
                  title: Text(action.label(l10n)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
      ],
    );
  }
}

/// What can be done with a document beyond opening it.
enum DocumentAction {
  save(Icons.download_rounded),
  share(Icons.ios_share_rounded),
  showInFolder(Icons.folder_open_rounded);

  const DocumentAction(this.icon);

  final IconData icon;

  String label(AppLocalizations l10n) => switch (this) {
    DocumentAction.save => l10n.messageSaveFile,
    DocumentAction.share => l10n.messageShareFile,
    DocumentAction.showInFolder => l10n.messageShowInFolder,
  };

  static Future<void> run(
    DocumentAction action,
    BuildContext context,
    WidgetRef ref, {
    required AttachmentEntity attachment,
    required String messageId,
  }) => switch (action) {
    DocumentAction.save => AttachmentActions.saveDocument(
      context,
      ref,
      attachment: attachment,
      messageId: messageId,
    ),
    DocumentAction.share => AttachmentActions.share(
      context,
      ref,
      attachment: attachment,
      messageId: messageId,
    ),
    DocumentAction.showInFolder => AttachmentActions.showInFolder(
      context,
      ref,
      attachment: attachment,
      messageId: messageId,
    ),
  };
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
