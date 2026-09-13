import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/core/theme/app_theme_extension.dart';
import 'package:chatix/core/theme/app_tokens.dart';
import 'package:chatix/features/chat/data/datasources/recent_media_source.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/domain/entities/chat_attachment_limits.dart';
import 'package:chatix/features/chat/presentation/providers/recent_media_provider.dart';
import 'package:chatix/features/chat/presentation/utils/chat_attachment_picker.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// What the composer should do once the sheet closes.
enum ComposerAttachmentKind {
  /// Files are picked and ready to be staged.
  uploads,

  /// Start a hands-free voice recording — the same thing the send button's
  /// lock gesture does, reached from the menu instead.
  recordVoice,

  /// Capture a video note.
  recordVideoNote,
}

class ComposerAttachmentResult {
  const ComposerAttachmentResult(this.kind, {this.uploads = const []});

  final ComposerAttachmentKind kind;
  final List<AttachmentUploadRequestEntity> uploads;
}

/// The composer's own attachment panel.
///
/// The point of not handing off to the system picker is the strip along the
/// top: the photo someone wants is almost always one of the last few they
/// took, and reaching it should not mean leaving the conversation. Anything
/// further away — the camera, a document, a recording — is a row underneath.
///
/// The limits from api-docs §5.5 are the sheet's, not the server's to
/// enforce after the fact: up to ten photos or videos, or exactly one
/// document, and a voice message or video note travels on its own.
///
/// There is deliberately no location row. Nothing in the API carries a
/// place, so a pin would be a message that cannot be sent.
class ComposerAttachmentSheet extends ConsumerStatefulWidget {
  const ComposerAttachmentSheet({super.key});

  /// Opens the panel and answers with what the composer should do, or null
  /// when it was dismissed.
  static Future<ComposerAttachmentResult?> show(BuildContext context) {
    return showModalBottomSheet<ComposerAttachmentResult>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => const ComposerAttachmentSheet(),
    );
  }

  @override
  ConsumerState<ComposerAttachmentSheet> createState() =>
      _ComposerAttachmentSheetState();
}

class _ComposerAttachmentSheetState
    extends ConsumerState<ComposerAttachmentSheet> {
  final _picked = <String>{};

  bool _isResolving = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // Asks for the grant the first time and re-reads the library after
    // that, so a photo taken a minute ago is already at the front.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(recentMediaProvider.notifier).load(),
    );
  }

  void _toggle(String id) {
    setState(() {
      _notice = null;

      if (_picked.remove(id)) return;
      if (_picked.length >= ChatAttachmentLimits.maxMediaCount) {
        _notice = AppLocalizations.of(
          context,
        ).attachMediaFull(ChatAttachmentLimits.maxMediaCount);
        return;
      }
      _picked.add(id);
    });
  }

  /// Reads the picked gallery items back as files, then hands them over.
  Future<void> _confirmPicked() async {
    if (_picked.isEmpty || _isResolving) return;
    setState(() => _isResolving = true);

    final source = ref.read(recentMediaSourceProvider);
    final uploads = <AttachmentUploadRequestEntity>[];
    for (final id in _picked) {
      final upload = await source.upload(id);
      if (upload != null) uploads.add(upload);
    }

    if (!mounted) return;

    if (uploads.isEmpty) {
      setState(() {
        _isResolving = false;
        _notice = AppLocalizations.of(context).attachUnavailable;
      });
      return;
    }

    Navigator.of(context).pop(
      ComposerAttachmentResult(
        ComposerAttachmentKind.uploads,
        uploads: uploads,
      ),
    );
  }

  Future<void> _pickFromSystem(
    Future<List<AttachmentUploadRequestEntity>> Function() pick,
  ) async {
    final uploads = await pick();
    if (!mounted) return;

    if (uploads.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    Navigator.of(context).pop(
      ComposerAttachmentResult(
        ComposerAttachmentKind.uploads,
        uploads: uploads,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final media = ref.watch(recentMediaProvider).value;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.62,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                0,
                AppSpacing.x4,
                AppSpacing.x2,
              ),
              child: Text(
                l10n.attachSheetTitle,
                style: theme.textTheme.titleSmall,
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                children: [
                  if (media != null && media.isSupported)
                    RecentMediaStrip(
                      state: media,
                      picked: _picked,
                      onToggle: _toggle,
                      onAllow: () => ref
                          .read(recentMediaProvider.notifier)
                          .load(force: true),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.x4,
                        AppSpacing.x1,
                        AppSpacing.x4,
                        AppSpacing.x1,
                      ),
                      child: Text(
                        _notice!,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: ChatixTheme.of(context).danger,
                        ),
                      ),
                    ),
                  // The strip only reaches the last couple of dozen, and on a
                  // platform with no readable gallery there is no strip at
                  // all — this row is how anything older is picked either way.
                  _Row(
                    icon: Icons.photo_library_outlined,
                    label: l10n.attachMedia,
                    subtitle: l10n.attachMediaLimits(
                      ChatAttachmentLimits.maxMediaCount,
                      ChatAttachmentLimits.formatBytes(
                        ChatAttachmentLimits.maxMediaSizeBytes,
                      ),
                    ),
                    onTap: () =>
                        _pickFromSystem(ChatAttachmentPicker.pickMedia),
                  ),
                  _Row(
                    icon: Icons.photo_camera_outlined,
                    label: l10n.attachCamera,
                    onTap: () =>
                        _pickFromSystem(ChatAttachmentPicker.takePhoto),
                  ),
                  _Row(
                    icon: Icons.description_outlined,
                    label: l10n.attachDocument,
                    subtitle: l10n.attachDocumentLimits(
                      ChatAttachmentLimits.formatBytes(
                        ChatAttachmentLimits.maxFileSizeBytes,
                      ),
                    ),
                    onTap: () =>
                        _pickFromSystem(ChatAttachmentPicker.pickDocument),
                  ),
                  _Row(
                    icon: Icons.mic_none_rounded,
                    label: l10n.attachVoice,
                    subtitle: l10n.attachVoiceHint(
                      ChatAttachmentLimits.maxVoiceDurationSeconds,
                    ),
                    onTap: () => Navigator.of(context).pop(
                      const ComposerAttachmentResult(
                        ComposerAttachmentKind.recordVoice,
                      ),
                    ),
                  ),
                  _Row(
                    icon: Icons.videocam_outlined,
                    label: l10n.attachVideoNote,
                    subtitle: l10n.attachVideoNoteHint(
                      ChatAttachmentLimits.maxVideoNoteDurationSeconds,
                      ChatAttachmentLimits.maxVideoNoteResolutionPx,
                    ),
                    onTap: () => Navigator.of(context).pop(
                      const ComposerAttachmentResult(
                        ComposerAttachmentKind.recordVideoNote,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_picked.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x2,
                ),
                child: FilledButton.icon(
                  onPressed: _isResolving ? null : _confirmPicked,
                  icon: _isResolving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.attachSendCount(_picked.length)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label, style: theme.textTheme.bodyMedium),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
      onTap: onTap,
    );
  }
}

/// The last couple of dozen things the camera roll has, in a row.
class RecentMediaStrip extends StatelessWidget {
  const RecentMediaStrip({
    super.key,
    required this.state,
    required this.picked,
    required this.onToggle,
    required this.onAllow,
  });

  final RecentMediaState state;
  final Set<String> picked;
  final ValueChanged<String> onToggle;
  final VoidCallback onAllow;

  static const double tile = 96;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (state.isDenied) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x1,
          AppSpacing.x4,
          AppSpacing.x3,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                l10n.attachGalleryDenied,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            TextButton(
              onPressed: onAllow,
              child: Text(l10n.attachGalleryAllow),
            ),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return state.isLoading
          ? const SizedBox(
              height: tile,
              child: Center(child: CircularProgressIndicator()),
            )
          : const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            0,
            AppSpacing.x4,
            AppSpacing.x1,
          ),
          child: Text(
            l10n.attachRecent,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        SizedBox(
          height: tile,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
            itemCount: state.items.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.x1),
            itemBuilder: (context, index) {
              final item = state.items[index];
              return RecentMediaTile(
                key: ValueKey(item.id),
                item: item,
                order: picked.toList().indexOf(item.id),
                onTap: () => onToggle(item.id),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
      ],
    );
  }
}

/// One square of the strip.
class RecentMediaTile extends ConsumerWidget {
  const RecentMediaTile({
    super.key,
    required this.item,
    required this.order,
    required this.onTap,
  });

  final RecentMediaItem item;

  /// Where this one sits in the picked set, or -1 when it is not picked.
  /// Shown as a number rather than a tick so the order of a batch is
  /// visible before it is sent.
  final int order;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final bytes = ref.watch(recentMediaThumbnailProvider(item.id)).value;
    final isPicked = order >= 0;

    return Semantics(
      button: true,
      selected: isPicked,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          width: RecentMediaStrip.tile,
          height: RecentMediaStrip.tile,
          padding: EdgeInsets.all(isPicked ? 5 : 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            color: isPicked ? scheme.primary : Colors.transparent,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.md - 2),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: scheme.surfaceContainerHighest),
                if (bytes != null) Image.memory(bytes, fit: BoxFit.cover),
                if (item.isVideo)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: _Chip(label: _duration(item.duration)),
                  ),
                if (isPicked)
                  Positioned(right: 4, top: 4, child: _Badge(order: order + 1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _duration(Duration value) {
    final minutes = value.inMinutes;
    final seconds = value.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.full),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primary,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '$order',
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
