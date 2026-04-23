import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';

enum MarketplaceTab {
  home('/home', 'Home', Icons.home_outlined, Icons.home_rounded),
  search('/search', 'Search', Icons.search_outlined, Icons.search),
  orders('/orders', 'Orders', Icons.receipt_long_outlined, Icons.receipt_long),
  profile('/profile', 'Profile', Icons.person_outline, Icons.person);

  const MarketplaceTab(this.route, this.label, this.icon, this.selectedIcon);

  final String route;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class MarketplaceBottomNavBar extends StatelessWidget {
  final MarketplaceTab currentTab;

  const MarketplaceBottomNavBar({super.key, required this.currentTab});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: NavigationBar(
        selectedIndex: currentTab.index,
        height: 72,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.surfaceMuted,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          final selectedTab = MarketplaceTab.values[index];
          if (selectedTab == currentTab) return;
          context.go(selectedTab.route);
        },
        destinations: [
          for (final tab in MarketplaceTab.values)
            NavigationDestination(
              icon: Icon(
                tab.icon,
                color: AppColors.textSecondary,
                size: 22,
              ),
              selectedIcon: Icon(
                tab.selectedIcon,
                color: AppColors.primary,
                size: 22,
              ),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}
