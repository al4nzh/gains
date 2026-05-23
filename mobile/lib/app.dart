import 'package:flutter/material.dart';
import 'package:gains/core/theme/app_theme.dart';
import 'package:gains/features/auth/session/auth_session.dart';
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

  @override
  void initState() {
    super.initState();
    _appRouter = AppRouter(widget.authSession);
    widget.authSession.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AuthSession>.value(
      value: widget.authSession,
      child: MaterialApp.router(
        title: 'Gains',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _appRouter.router,
      ),
    );
  }
}
