import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../config/routes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common_widgets.dart';

/// Profile screen — shows user info and trip statistics.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth  = context.watch<AuthProvider>();
    final trips = context.watch<TripProvider>().tripHistory;
    final user  = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Avatar + name
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    (user?.name.isNotEmpty == true) ? user!.name[0].toUpperCase() : 'T',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(user?.name ?? 'Traveller', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Stats row
          Row(
            children: [
              _StatCard(value: '${trips.length}', label: 'Trips'),
              const SizedBox(width: 12),
              _StatCard(
                value: '${trips.fold<int>(0, (s, t) => s + t.days)}',
                label: 'Total Days',
              ),
              const SizedBox(width: 12),
              _StatCard(
                value: '${trips.where((t) => t.storyTitle != null).length}',
                label: 'Reels',
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Menu items
          TBSectionHeader(title: 'Account'),
          const SizedBox(height: 12),
          _MenuItem(icon: Icons.history, label: 'Trip History', onTap: () {}),
          _MenuItem(icon: Icons.download_outlined, label: 'Downloads', onTap: () {}),
          _MenuItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
          ),
          const Divider(height: 32),
          _MenuItem(
            icon: Icons.logout,
            label: 'Sign Out',
            color: AppTheme.error,
            onTap: () async {
              await context.read<AuthProvider>().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (_) => false);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TBCard(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, color: c),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: c)),
      trailing: Icon(Icons.chevron_right, color: AppTheme.textHint),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}
