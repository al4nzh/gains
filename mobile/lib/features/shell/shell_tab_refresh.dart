import 'package:flutter/foundation.dart';

/// Tab indices matching [AppShell] bottom navigation order.
abstract final class ShellTab {
  static const home = 0;
  static const train = 1;
  static const routines = 2;
  static const progress = 3;
  static const coach = 4;
}

/// Notifies tab screens to reload when the user switches tabs or completes an action.
class ShellTabRefresh extends ChangeNotifier {
  final List<int> _ticks = List.filled(5, 0);

  int tick(int tabIndex) => _ticks[tabIndex];

  void bump(int tabIndex) {
    _ticks[tabIndex]++;
    notifyListeners();
  }

  void bumpMany(Iterable<int> tabIndices) {
    for (final i in tabIndices) {
      _ticks[i]++;
    }
    notifyListeners();
  }
}
