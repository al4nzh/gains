import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/brand_mark.dart';
import 'package:gains/core/widgets/gains_scaffold.dart';
import 'package:gains/features/auth/presentation/widgets/oauth_sign_in_buttons.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GainsScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          const BrandMark(),
          const Spacer(flex: 3),
          const OAuthSignInButtons(),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/register'),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => context.push('/login'),
            child: const Text('Log in with email'),
          ),
          const SizedBox(height: 24),
          Text(
            'Train smarter. Track strength, recovery, and progress.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
