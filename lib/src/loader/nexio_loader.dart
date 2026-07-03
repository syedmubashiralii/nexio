import 'package:flutter/material.dart';

/// Presents a global or per-request loader without forcing app design.
class NexioLoaderController {
  /// Creates a loader controller.
  ///
  /// Parameters:
  /// - [navigatorKey] is used when a request does not provide a context.
  NexioLoaderController({this.navigatorKey});

  /// Navigator key used for global loader presentation.
  final GlobalKey<NavigatorState>? navigatorKey;

  int _visibleCount = 0;
  bool _dialogVisible = false;

  /// Shows the loader.
  ///
  /// Parameters:
  /// - [context] is preferred when the caller wants a specific navigator.
  /// - [loaderWidget] customizes the visual loader.
  /// - [dismissible] controls whether the barrier can be dismissed.
  /// - [barrierColor] customizes the barrier color.
  void show({
    BuildContext? context,
    Widget? loaderWidget,
    bool dismissible = false,
    Color? barrierColor,
  }) {
    _visibleCount += 1;
    if (_dialogVisible) {
      return;
    }

    final targetContext = context ?? navigatorKey?.currentContext;
    if (targetContext == null) {
      return;
    }

    _dialogVisible = true;
    showDialog<void>(
      context: targetContext,
      barrierDismissible: dismissible,
      barrierColor: barrierColor ?? const Color(0x99000000),
      builder: (_) {
        return Center(
          child: loaderWidget ??
              const SizedBox.square(
                dimension: 44,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
        );
      },
    );
  }

  /// Hides one loader request.
  void hide() {
    if (_visibleCount > 0) {
      _visibleCount -= 1;
    }
    if (_visibleCount > 0 || !_dialogVisible) {
      return;
    }
    final navigator = navigatorKey?.currentState;
    if (navigator?.canPop() ?? false) {
      navigator?.pop();
    }
    _dialogVisible = false;
  }
}
