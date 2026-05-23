import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:provider/provider.dart';

class ProfileMenuScreen extends StatelessWidget {
  const ProfileMenuScreen({super.key});

  void _stub(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — coming soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    final user = session.user;
    final profile = session.profile;

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
            leading: const Icon(Icons.person_outline),
            title: const Text('Edit profile'),
            onTap: () => _stub(context, 'Edit profile'),
          ),
          ListTile(
            leading: const Icon(Icons.bedtime_outlined),
            title: const Text('Recovery log'),
            onTap: () => _stub(context, 'Recovery log'),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Physique scans'),
            onTap: () => _stub(context, 'Physique scans'),
          ),
          const Divider(height: 1),
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
