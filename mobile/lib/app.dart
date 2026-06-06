import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_theme.dart';
import 'package:gains/core/widgets/dev_api_banner.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:gains/router/app_router.dart';
import 'package:provider/provider.dart';

class GainsApp extends StatefulWidget {
  const GainsApp({super.key, required this.authSession});

  final AuthSession authSession;

  @override
  State<GainsApp> createState() => _GainsAppState();
}

class _GainsAppState extends State<GainsApp> {
  late final AppRouter _appRouter;
  late final ShellTabRefresh _shellTabRefresh;

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authSession);
    _shellTabRefresh = ShellTabRefresh();
    widget.authSession.bootstrap();
  }

  @override
  void dispose() {
    _shellTabRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ShellTabRefresh>.value(
      value: _shellTabRefresh,
      child: MaterialApp.router(
        title: 'Gains',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _appRouter.router,
        builder: (context, child) {
          if (child == null) return const SizedBox.shrink();
          return DevApiDebugShell(child: child);
        },
      ),
    );
  }
}
