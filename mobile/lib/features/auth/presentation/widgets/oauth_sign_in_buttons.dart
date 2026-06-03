import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/config/oauth_config.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/auth/data/oauth_service.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class OAuthSignInButtons extends StatefulWidget {
  const OAuthSignInButtons({super.key});

  @override
  State<OAuthSignInButtons> createState() => _OAuthSignInButtonsState();
}

enum _OAuthProvider { google, apple }

class _OAuthSignInButtonsState extends State<OAuthSignInButtons> {
  _OAuthProvider? _loading;

  Future<void> _run(_OAuthProvider provider, Future<void> Function() action) async {
    if (_loading != null) return;
    setState(() => _loading = provider);
    final session = context.read<AuthSession>();

    try {
      await action();
      if (!mounted) return;
      context.go(session.needsOnboarding ? '/onboarding' : '/home');
    } on OAuthSignInException catch (e) {
      if (!mounted || e.cancelled) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showGoogle = OAuthConfig.isGoogleConfigured || Platform.isAndroid || Platform.isIOS;
    final showApple = Platform.isIOS || Platform.isMacOS;

    if (!showGoogle && !showApple) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(child: Divider(color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'or',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ),
            const Expanded(child: Divider(color: AppColors.border)),
          ],
        ),
        const SizedBox(height: 16),
        if (showGoogle)
          OutlinedButton.icon(
            onPressed: _loading != null
                ? null
                : () => _run(
                      _OAuthProvider.google,
                      context.read<AuthSession>().signInWithGoogle,
                    ),
            icon: _loading == _OAuthProvider.google
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.g_mobiledata, size: 28),
            label: const Text('Continue with Google'),
          ),
        if (showGoogle && showApple) const SizedBox(height: 12),
        if (showApple)
          OutlinedButton.icon(
            onPressed: _loading != null
                ? null
                : () => _run(
                      _OAuthProvider.apple,
                      context.read<AuthSession>().signInWithApple,
                    ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
            ),
            icon: _loading == _OAuthProvider.apple
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.apple, size: 22),
            label: const Text('Continue with Apple'),
          ),
      ],
    );
  }
}
