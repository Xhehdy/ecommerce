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
    return NavigationBar(
      selectedIndex: currentTab.index,
      height: 76,
      onDestinationSelected: (index) {
        final selectedTab = MarketplaceTab.values[index];
        if (selectedTab == currentTab) {
          return;
        }

        context.go(selectedTab.route);
      },
      destinations: [
        for (final tab in MarketplaceTab.values)
          NavigationDestination(
            icon: Icon(tab.icon, color: AppColors.textSecondary),
            selectedIcon: Icon(tab.selectedIcon, color: AppColors.primary),
            label: tab.label,
          ),
      ],
    );
  }
}
