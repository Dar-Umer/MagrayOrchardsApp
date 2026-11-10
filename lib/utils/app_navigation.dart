import 'package:flutter/material.dart';

/// Coordinates root-tab switches from nested screens or snackbars without
/// coupling child widgets directly to [HomeScreen].
class AppNavigation {
  AppNavigation._();

  static final ValueNotifier<int?> requestedTab = ValueNotifier<int?>(null);

  static void goToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    requestedTab.value = tabIndex;
  }

  static void openCart(BuildContext context) => goToTab(context, 3);
}
