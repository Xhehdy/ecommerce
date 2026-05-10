import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
              return;
            }
            context.go('/profile');
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.person_outline,
                  title: 'Profile details',
                  subtitle: 'Name, faculty, matric number, and phone',
                  onTap: () => context.go('/profile'),
                ),
                const Divider(height: 1, color: AppColors.border),
                _SettingsTile(
                  icon: Icons.notifications_none_outlined,
                  title: 'Notifications',
                  subtitle: 'Order, sale, and saved-item alerts',
                  onTap: () => context.push('/notifications'),
                ),
                const Divider(height: 1, color: AppColors.border),
                _SettingsTile(
                  icon: Icons.receipt_long_outlined,
                  title: 'Orders',
                  subtitle: 'Purchases, sales, handoff, and payment status',
                  onTap: () => context.push('/orders'),
                ),
                const Divider(height: 1, color: AppColors.border),
                _SettingsTile(
                  icon: Icons.favorite_border_rounded,
                  title: 'Saved items',
                  subtitle: 'Products you may want to buy later',
                  onTap: () => context.push('/saved'),
                ),
                const Divider(height: 1, color: AppColors.border),
                _SettingsTile(
                  icon: Icons.help_outline_rounded,
                  title: 'Help Center',
                  subtitle: 'Buying, selling, payments, and safety',
                  onTap: () => context.push('/help'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primaryDark),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
