import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chatix/core/router/app_routes.dart';
import 'package:chatix/core/ui/desktop/desktop_input.dart';
import 'package:chatix/features/chat/presentation/providers/chat_profile_provider.dart';
import 'package:chatix/features/chat/presentation/providers/chat_switch_provider.dart';
import 'package:chatix/features/chat/presentation/providers/search_history_provider.dart';
import 'package:chatix/features/chat/presentation/widgets/chat_jump_palette.dart';

/// The keys that work anywhere in the shell, on a desktop.
///
/// * Ctrl/Cmd+K — the palette: jump to a chat by its name.
/// * Ctrl/Cmd+F — search the open chat, or everything when none is open.
/// * Ctrl/Cmd+, — settings.
/// * Alt+↑/↓, Ctrl+Shift+Tab/Ctrl+Tab — the chat above or below in the list.
///
/// Registered with the app's [ShortcutRegistry] rather than wrapped around
/// the shell: the registry sits above every navigator, so the keys arrive
/// wherever the focus is — in a pane, in a text field, or on the shell's own
/// route, where focus settles after a switch of tabs and where shortcuts
/// wrapped around the shell would never hear them. It also sits below the
/// app-wide text editing keys, so Alt+↑ switches chats even with the caret
/// in the composer, as in desktop messengers; none of the others is a text
/// editing key. While a dialog or a full-screen page covers the shell they
/// are taken back out of the registry. On a phone none of them is ever
/// registered.
class AppShellShortcuts extends ConsumerStatefulWidget {
  const AppShellShortcuts({
    super.key,
    required this.onOpenSettings,
    required this.child,
  });

  final VoidCallback onOpenSettings;
  final Widget child;

  @override
  ConsumerState<AppShellShortcuts> createState() => _AppShellShortcutsState();
}

class _AppShellShortcutsState extends ConsumerState<AppShellShortcuts> {
  ShortcutRegistryEntry? _entry;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!DesktopInput.isDesktop) return;

    // Registered only while the shell is the page on top. Under a dialog —
    // the palette included — or a page that covers it, the keys go back to
    // whatever has the focus there: Alt+↑ is that text field's again.
    final onTop = ModalRoute.of(context)?.isCurrent ?? true;
    if (onTop && _entry == null) {
      _entry = ShortcutRegistry.of(context).addAll(_bindings());
    } else if (!onTop && _entry != null) {
      _entry!.dispose();
      _entry = null;
    }
  }

  @override
  void dispose() {
    _entry?.dispose();
    super.dispose();
  }

  Map<ShortcutActivator, Intent> _bindings() {
    VoidCallbackIntent run(VoidCallback action) => VoidCallbackIntent(() {
      if (mounted) action();
    });

    return {
      DesktopInput.primary(LogicalKeyboardKey.keyK): run(
        () => unawaited(_jump()),
      ),
      DesktopInput.primary(LogicalKeyboardKey.keyF): run(_search),
      DesktopInput.primary(LogicalKeyboardKey.comma): run(
        () => widget.onOpenSettings(),
      ),
      const SingleActivator(LogicalKeyboardKey.arrowUp, alt: true): run(
        () => _step(-1),
      ),
      const SingleActivator(LogicalKeyboardKey.arrowDown, alt: true): run(
        () => _step(1),
      ),
      const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
          run(() => _step(-1)),
      const SingleActivator(LogicalKeyboardKey.tab, control: true): run(
        () => _step(1),
      ),
    };
  }

  /// The palette, then the chat picked in it.
  Future<void> _jump() async {
    final router = GoRouter.of(context);
    final chatId = await ChatJumpPalette.show(context);
    if (chatId == null || !mounted) return;

    // A choice by name, like one in search: it is what "recent" means there.
    ref.read(searchHistoryProvider.notifier).rememberChat(chatId);
    router.go(ChatDetailRoute(chatId).location);
  }

  /// The open chat's own search field — the screen is listening for the
  /// request — or the search over everything when no chat is on screen.
  void _search() {
    final router = GoRouter.of(context);
    final chatId = ChatSwitching.visibleChatId(router);

    if (chatId != null) {
      ref.read(chatSearchRequestProvider.notifier).open(chatId);
      return;
    }
    unawaited(router.push<void>(ChatSearchRoute.location));
  }

  /// The chat [step] rows away in the list, replacing the open one rather
  /// than stacking on it: walking through ten chats should not leave ten
  /// pages to walk back through.
  void _step(int step) {
    final router = GoRouter.of(context);
    final target = ChatSwitching.neighbour(
      ref.read(visibleChatOrderProvider),
      ChatSwitching.currentChatId(router),
      step,
    );
    if (target == null) return;

    router.go(ChatDetailRoute(target).location);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
