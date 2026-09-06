import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocalizationRouterObserver extends NavigatorObserver {
  LocalizationRouterObserver(this.ref);
  final WidgetRef ref;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _refreshRouteWithCurrentLocale(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _refreshRouteWithCurrentLocale(newRoute);
    }
  }

  void _refreshRouteWithCurrentLocale(Route<dynamic> route) {
  }

  void onLocaleChanged(Locale locale) {
  }
}

final localizationRouterObserverProvider = Provider<NavigatorObserver>((ref) {
  return _LocalizationRouterObserverWithRef(ref);
});

class _LocalizationRouterObserverWithRef extends NavigatorObserver {
  _LocalizationRouterObserverWithRef(this.ref);
  final Ref ref;

}

extension LocaleAwareNavigation on BuildContext {
  void goWithLocale(String location) {
    GoRouter.of(this).go(location);
  }

  void goNamedWithLocale(
    String name, {
    Map<String, String> pathParameters = const {},
  }) {
    GoRouter.of(this).goNamed(name, pathParameters: pathParameters);
  }
}
