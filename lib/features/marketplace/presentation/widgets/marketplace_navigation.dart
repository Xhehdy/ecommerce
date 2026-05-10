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
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
        ),
        child: Row(
          children: [
            for (final tab in MarketplaceTab.values)
              Expanded(
                child: _BottomNavItem(
                  tab: tab,
                  selected: tab == currentTab,
                  onTap: () {
                    if (tab == currentTab) return;
                    context.go(tab.route);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final MarketplaceTab tab;
  final bool selected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 30,
              width: 58,
              decoration: BoxDecoration(
                color: selected ? AppColors.surfaceMuted : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                selected ? tab.selectedIcon : tab.icon,
                color: selected ? AppColors.primary : AppColors.textSecondary,
                size: 21,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
