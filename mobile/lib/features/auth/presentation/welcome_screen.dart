import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/brand_mark.dart';
import 'package:gains/core/widgets/gains_scaffold.dart';
import 'package:gains/core/widgets/legal_footer.dart';
import 'package:gains/features/auth/presentation/widgets/oauth_sign_in_buttons.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _features = [
    (Icons.fitness_center_outlined, 'Log workouts', 'Sets, RPE, PRs, and strength Elo'),
    (Icons.insights_outlined, 'Train smarter', 'Recovery check-ins and a daily sharpness score'),
    (Icons.smart_toy_outlined, 'AI coach', 'Chat, routines, and post-workout insights'),
  ];

  @override
  Widget build(BuildContext context) {
    return GainsScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          const BrandMark(),
          const SizedBox(height: 28),
          Text(
            'Strength training,\npersonalized',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: 20),
          ..._features.map((f) => _FeatureRow(icon: f.$1, title: f.$2, subtitle: f.$3)),
          const Spacer(),
          const OAuthSignInButtons(),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => context.push('/register'),
            child: const Text('Create account'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => context.push('/login'),
            child: const Text('Log in with email'),
          ),
          const SizedBox(height: 16),
          const LegalFooter(),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
