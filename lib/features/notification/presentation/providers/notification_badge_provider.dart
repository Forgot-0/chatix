import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chatix/features/auth/presentation/providers/auth_provider.dart';
import 'package:chatix/features/notification/presentation/providers/notification_providers.dart';

const _pollInterval = Duration(minutes: 1);

class NotificationBadgeController extends Notifier<int> {
  Timer? _timer;
  AppLifecycleListener? _lifecycleListener;

  bool _inFlight = false;

  @override
  int build() {
    final isAuthenticated = ref.watch(authProvider).isAuthenticated;

    ref.onDispose(_stop);

    if (!isAuthenticated) {
      _stop();
      return 0;
    }

    _start();

    scheduleMicrotask(refresh);

    return stateOrNull ?? 0;
  }

  void _start() {
    _timer ??= Timer.periodic(_pollInterval, (_) => refresh());
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () {
        _timer ??= Timer.periodic(_pollInterval, (_) => refresh());
        refresh();
      },
      onPause: () {
        _timer?.cancel();
        _timer = null;
      },
    );
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }

  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final result = await ref.read(getUnreadCountUseCaseProvider).execute();
      if (!ref.mounted) return;
      result.match((_) {}, (count) => state = count);
    } finally {
      _inFlight = false;
    }
  }

  void decrementBy(int amount) {
    if (amount <= 0) return;
    final next = state - amount;
    state = next < 0 ? 0 : next;
  }

  void clear() => state = 0;
}

final notificationBadgeProvider =
    NotifierProvider<NotificationBadgeController, int>(
      NotificationBadgeController.new,
    );
