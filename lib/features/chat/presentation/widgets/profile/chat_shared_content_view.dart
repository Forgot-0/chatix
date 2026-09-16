import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/states/app_async_states.dart';
import 'package:chatix/features/chat/domain/entities/attachment_entity.dart';
import 'package:chatix/features/chat/presentation/utils/chat_shared_content.dart';
import 'package:chatix/features/chat/presentation/utils/chat_timestamp.dart';
import 'package:chatix/features/chat/presentation/widgets/attachment_preview.dart';
import 'package:chatix/features/chat/presentation/widgets/document_attachment_row.dart';
import 'package:chatix/features/chat/presentation/widgets/voice_player.dart';
import 'package:chatix/gen/l10n/app_localizations.dart';

/// One tab's worth of what a chat has shared, as a sliver.
///
/// A sliver rather than a scroll view of its own so it can sit in the same
/// [CustomScrollView] as the collapsing header — the tabs scroll the page,
/// they do not scroll inside it.
///
/// Every tab ends on a line saying the list is what this device holds, not
/// what the chat holds: there is no shared-media endpoint in the API (see
/// [ChatSharedContent]), so it would otherwise read as the whole history.
class ChatSharedContentSliver extends StatelessWidget {
  const ChatSharedContentSliver({
    super.key,
    required this.chatId,
    required this.tab,
    required this.content,
  });

  final String chatId;
  final SharedContentTab tab;
  final ChatSharedContent content;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // An empty tab is exactly when the note matters most: without it, "no
    // files here" reads as a fact about the chat rather than about what this
    // device has loaded.
    if (content.countOf(tab) == 0) {
      return SliverToBoxAdapter(
        child: Column(
          children: [
            const SizedBox(height: 24),
            AppInlineEmpty(title: _emptyMessage(l10n)),
            const _ScopeNote(),
          ],
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        switch (tab) {
          SharedContentTab.media => _mediaGrid(),
          SharedContentTab.files => _filesList(context),
          SharedContentTab.links => _linksList(context, l10n),
          SharedContentTab.voice => _voiceList(context),
        },
        const SliverToBoxAdapter(child: _ScopeNote()),
      ],
    );
  }

  String _emptyMessage(AppLocalizations l10n) => switch (tab) {
    SharedContentTab.media => l10n.sharedMediaEmpty,
    SharedContentTab.files => l10n.sharedFilesEmpty,
    SharedContentTab.links => l10n.sharedLinksEmpty,
    SharedContentTab.voice => l10n.sharedVoiceEmpty,
  };

  Widget _mediaGrid() {
    final items = content.media;

    return SliverPadding(
      padding: const EdgeInsets.all(2),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 140,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) =>
            _MediaTile(chatId: chatId, item: items[index]),
      ),
    );
  }

  Widget _filesList(BuildContext context) {
    final items = content.files;
    final scheme = Theme.of(context).colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) => DocumentAttachmentRow(
          attachment: items[index].attachment,
          messageId: items[index].messageId,
          foreground: scheme.onSurface,
        ),
      ),
    );
  }

  Widget _voiceList(BuildContext context) {
    final items = content.voice;
    final scheme = Theme.of(context).colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) => VoicePlayer(
          attachment: items[index].attachment,
          messageId: items[index].messageId,
          foreground: scheme.onSurface,
          accent: scheme.primary,
          author: items[index].message.profile,
          authorId: items[index].message.authorId,
        ),
      ),
    );
  }

  Widget _linksList(BuildContext context, AppLocalizations l10n) {
    final items = content.links;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final scheme = Theme.of(context).colorScheme;

    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final when = formatChatTimestamp(
          item.message.createdAt,
          l10n,
          locale: locale,
        );

        return ListTile(
          leading: const Icon(Icons.link),
          title: Text(
            item.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: scheme.primary),
          ),
          subtitle: Text(
            '${item.message.authorLabel} · $when',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _openLink(context, item.target),
        );
      },
    );
  }

  Future<void> _openLink(BuildContext context, String target) async {
    final uri = Uri.tryParse(target);
    final opened =
        uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).linkOpenFailed)),
    );
  }
}

class _ScopeNote extends StatelessWidget {
  const _ScopeNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Text(
        AppLocalizations.of(context).sharedContentLocalOnly,
        textAlign: TextAlign.center,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.chatId, required this.item});

  final String chatId;
  final SharedAttachment item;

  /// Anything that plays gets a marker; a still photo does not need one.
  bool get _plays => item.attachment.attachmentType != AttachmentType.image;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        ChatMediaRoute(
          chatId,
          messageId: item.messageId,
          attachmentId: item.attachmentId,
        ).location,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AttachmentImage(
            attachment: item.attachment,
            messageId: item.messageId,
            borderRadius: BorderRadius.zero,
          ),
          if (_plays)
            const Align(
              alignment: Alignment.bottomLeft,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.play_circle_outline,
                  size: 20,
                  // On top of a photo, which has no theme of its own.
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
