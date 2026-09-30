import 'package:flutter/material.dart';

import 'package:iconstruct/core/navigation/progress_guard.dart';
import 'package:iconstruct/features/auth/presentation/screens/main_home_screen.dart';

/// Route names the app looks for in its own stack.
abstract final class AppRoutes {
  static const String home = 'home';
}

/// Keeps a copy of the root navigator's stack so navigation can ask what is
/// under the current screen, which [NavigatorState] does not expose.
class NavigationHistory extends NavigatorObserver {
  NavigationHistory._();

  static final NavigationHistory instance = NavigationHistory._();

  final List<Route<dynamic>> _stack = [];

  /// Whether the signed-in home screen is somewhere in the stack.
  bool get hasHome => _stack.any((r) => r.settings.name == AppRoutes.home);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) _stack.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (newRoute is! PageRoute) {
      if (index >= 0) _stack.removeAt(index);
      return;
    }
    if (index >= 0) {
      _stack[index] = newRoute;
    } else {
      _stack.add(newRoute);
    }
  }
}

/// Back and tab navigation that lands on the right screen.
///
/// A plain `Navigator.pop` is only right when the screen was pushed over its
/// parent. Screens reached through `pushAndRemoveUntil` (sign-out, tabs) or a
/// notification can be the root, where pop does nothing or leaves the app.
class AppNav {
  const AppNav._();

  static Route<void> homeRoute({bool forceHomeGuide = false}) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: AppRoutes.home),
      builder: (_) => MainHomeScreen(forceHomeGuide: forceHomeGuide),
    );
  }

  /// Clears the stack down to a fresh home screen.
  static void goHome(BuildContext context, {bool forceHomeGuide = false}) {
    Navigator.of(context).pushAndRemoveUntil(
      homeRoute(forceHomeGuide: forceHomeGuide),
      (_) => false,
    );
  }

  /// The header back button. Pops through any [ProgressGuard] or [PopScope]
  /// on the route; on a root screen goes to [rootFallback], or home.
  static Future<void> back(
    BuildContext context, {
    WidgetBuilder? rootFallback,
  }) async {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      await navigator.maybePop();
      return;
    }
    if (rootFallback != null) {
      navigator.pushReplacement(MaterialPageRoute<void>(builder: rootFallback));
      return;
    }
    navigator.pushReplacement(homeRoute());
  }

  /// A bottom-navigation destination. Tabs sit directly over home, so back
  /// from any tab returns home instead of through every tab visited before.
  ///
  /// Leaving mid-estimate asks first: the estimate's screens are dropped.
  static Future<void> openTab(BuildContext context, WidgetBuilder tab) async {
    if (!await ProgressGuard.confirmExit(context)) return;
    if (!context.mounted) return;
    final navigator = Navigator.of(context);
    navigator.pushAndRemoveUntil(homeRoute(), (_) => false);
    navigator.push(MaterialPageRoute<void>(builder: tab));
  }

  /// The Home tab.
  static Future<void> openHomeTab(BuildContext context) async {
    if (!await ProgressGuard.confirmExit(context)) return;
    if (!context.mounted) return;
    goHome(context);
  }

  /// Opens a notification's target. Pushed over whatever the builder is
  /// doing, so back returns there; but when home is not in the stack (a cold
  /// start over the splash screen), home goes underneath first so back does
  /// not land on the splash or close the app.
  static void openFromNotification(
    NavigatorState navigator,
    Route<void> route,
  ) {
    if (!NavigationHistory.instance.hasHome) {
      navigator.pushAndRemoveUntil(homeRoute(), (_) => false);
    }
    navigator.push(route);
  }
}

/// Handles system back on a screen that can end up as the root of the stack,
/// such as sign-in after signing out: it goes to [fallback] instead of
/// closing the app.
class RootBackFallback extends StatelessWidget {
  final WidgetBuilder fallback;
  final Widget child;

  const RootBackFallback({
    super.key,
    required this.fallback,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isRoot = ModalRoute.of(context)?.isFirst ?? false;
    if (!isRoot) return child;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute<void>(builder: fallback));
      },
      child: child,
    );
  }
}
