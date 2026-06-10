import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/utils/support_contact.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/subscription/presentation/paywall_sheet.dart';
import 'package:gains/features/subscription/services/subscription_service.dart';
import 'package:provider/provider.dart';

class ProfileMenuScreen extends StatelessWidget {
  const ProfileMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.user;
    final profile = session.profile;
    final isPremium = context.watch<SubscriptionService>().isPremium;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (user != null)
            ListTile(
              title: Text(user.email),
              subtitle: Text(
                profile?.goal != null
                    ? '${profile!.goal} · ${profile.experience ?? ''}'
                    : 'Gains account',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined,
              color: isPremium ? AppColors.primary : null,
            ),
            title: Text(isPremium ? 'Gains Premium' : 'Upgrade to Premium'),
            subtitle: Text(
              isPremium ? 'AI coach and advanced tools unlocked' : 'Unlock AI coach, scans, and more',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => showPaywallSheet(context),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit profile'),
            onTap: () => context.push('/profile/edit'),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Recovery log'),
            onTap: () => context.push('/profile/recovery'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Physique scans'),
            onTap: () => context.push('/physique-scans'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & support'),
            subtitle: const Text(
              'Questions, bugs, or account help',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            onTap: () => openSupportContact(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
            title: const Text('Delete account', style: TextStyle(color: AppColors.error)),
            onTap: () => _confirmDeleteAccount(context, session),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.error),
            title: const Text('Log out', style: TextStyle(color: AppColors.error)),
            onTap: () async {
              await session.logout();
              if (context.mounted) context.go('/welcome');
            },
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteAccount(BuildContext context, AuthSession session) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete account?'),
      content: const Text(
        'This permanently deletes your Gains account, workouts, routines, and all other data. This cannot be undone.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await session.deleteAccount();
    if (context.mounted) context.go('/welcome');
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete account. Try again.')),
      );
    }
  }
}
