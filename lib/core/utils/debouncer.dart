import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs an action once things have been quiet for [delay].
///
/// Each [run] cancels the one before it, so a burst of calls — keystrokes in
/// a search box — turns into a single action [delay] after the last of them.
/// Owned by whoever calls it and cancelled in their `dispose`, so no timer
/// outlives the screen that started it.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;

  Timer? _timer;

  /// Whether an action is waiting to run.
  bool get isPending => _timer?.isActive ?? false;

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  /// Drops whatever is waiting and runs [action] at once — Enter in a search
  /// box that would otherwise still be counting down.
  void runNow(VoidCallback action) {
    cancel();
    action();
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
