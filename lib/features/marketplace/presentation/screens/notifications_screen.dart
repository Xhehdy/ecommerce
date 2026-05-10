import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/ui/snackbars.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _orderUpdates = true;
  bool _sellerActivity = true;
  bool _savedItemAlerts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Container(
                  height: 68,
                  width: 68,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceMuted,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: AppColors.primaryDark,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No alerts right now',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Order, sale, and saved-item updates will show up here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/orders'),
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: const Text('Open orders'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/saved'),
                  icon: const Icon(Icons.favorite_border_rounded, size: 18),
                  label: const Text('View saved items'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Preferences',
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
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  value: _orderUpdates,
                  title: const Text('Order updates'),
                  subtitle: const Text(
                    'Payment, reservation, and handoff changes',
                  ),
                  onChanged: (value) => setState(() => _orderUpdates = value),
                ),
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile.adaptive(
                  value: _sellerActivity,
                  title: const Text('Seller activity'),
                  subtitle: const Text('New sales and listing status changes'),
                  onChanged: (value) => setState(() => _sellerActivity = value),
                ),
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile.adaptive(
                  value: _savedItemAlerts,
                  title: const Text('Saved item alerts'),
                  subtitle: const Text('Updates for items you have saved'),
                  onChanged: (value) =>
                      setState(() => _savedItemAlerts = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              AppSnackbars.showSuccess(
                context,
                'Notification preferences saved.',
              );
            },
            child: const Text('Save preferences'),
          ),
        ],
      ),
    );
  }
}
