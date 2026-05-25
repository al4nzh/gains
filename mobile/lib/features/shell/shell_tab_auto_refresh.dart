import 'package:flutter/material.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

/// Reloads when [ShellTabRefresh] bumps [tabIndex].
mixin ShellTabAutoRefresh<T extends StatefulWidget> on State<T> {
  int get shellTabIndex;

  ShellTabRefresh? _shellRefresh;
  int _lastTick = 0;

  void onShellTabRefresh();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<ShellTabRefresh>();
    if (_shellRefresh != next) {
      _shellRefresh?.removeListener(_handleShellRefresh);
      _shellRefresh = next;
      _lastTick = next.tick(shellTabIndex);
      _shellRefresh!.addListener(_handleShellRefresh);
    }
  }

  void _handleShellRefresh() {
    final hub = _shellRefresh;
    if (hub == null) return;
    final tick = hub.tick(shellTabIndex);
    if (tick != _lastTick) {
      _lastTick = tick;
      onShellTabRefresh();
    }
  }

  @override
  void dispose() {
    _shellRefresh?.removeListener(_handleShellRefresh);
    super.dispose();
  }
}
