import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help Center'),
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
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                  size: 30,
                ),
                const SizedBox(height: 14),
                const Text(
                  'Safer campus trades',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Keep payments in-app, meet in public campus spots, and confirm item condition before handoff.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _HelpSection(
            title: 'Buying',
            children: const [
              _HelpTile(
                title: 'Before checkout',
                subtitle:
                    'Review photos, condition, price, and pickup location.',
                icon: Icons.fact_check_outlined,
              ),
              _HelpTile(
                title: 'After payment',
                subtitle:
                    'Your order appears under Purchases with seller details.',
                icon: Icons.receipt_long_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _HelpSection(
            title: 'Selling',
            children: const [
              _HelpTile(
                title: 'Create strong listings',
                subtitle:
                    'Use clear photos, fair pricing, and a specific pickup spot.',
                icon: Icons.add_photo_alternate_outlined,
              ),
              _HelpTile(
                title: 'Manage status',
                subtitle: 'Mark items sold or available from My Listings.',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
          const SizedBox(height: 18),
          _HelpSection(
            title: 'Trust & Support',
            children: const [
              _HelpTile(
                title: 'Report a listing',
                subtitle: 'Open a product and use Report listing for review.',
                icon: Icons.flag_outlined,
              ),
              _HelpTile(
                title: 'Payment issues',
                subtitle:
                    'Cancelled payments release the listing back to buyers.',
                icon: Icons.payments_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _HelpSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _HelpTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _HelpTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primaryDark),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
    );
  }
}
