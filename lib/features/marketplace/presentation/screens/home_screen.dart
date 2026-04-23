import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/ui/snackbars.dart';
import '../../../auth/application/auth_provider.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../widgets/marketplace_navigation.dart';
import '../widgets/product_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int? _selectedCategoryId;
  bool _showPromoBanner = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(authControllerProvider).ensureCurrentUserProfile();
        ref.invalidate(profileProvider);
      } catch (error) {
        if (!mounted) return;
        AppSnackbars.showError(context, error);
      }
    });
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_selectedCategoryId == null) {
      return products;
    }
    return products
        .where((product) => product.categoryId == _selectedCategoryId)
        .toList(growable: false);
  }

  IconData _iconForCategory(String? name) {
    if (name == null) return Icons.category_outlined;
    final lower = name.toLowerCase();
    if (lower.contains('book')) return Icons.menu_book_outlined;
    if (lower.contains('electronic')) return Icons.computer_outlined;
    if (lower.contains('fashion')) return Icons.checkroom_outlined;
    if (lower.contains('beauty')) return Icons.face_retouching_natural;
    if (lower.contains('home') || lower.contains('hostel')) return Icons.chair_outlined;
    if (lower.contains('sport')) return Icons.sports_basketball_outlined;
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final feedAsync = ref.watch(homeFeedProvider);
    final categories = categoriesAsync.asData?.value ?? const <Category>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ATELIER.',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () => context.push('/favorites'),
          ),
        ],
      ),
      bottomNavigationBar: const MarketplaceBottomNavBar(
        currentTab: MarketplaceTab.home,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeFeedProvider);
          ref.invalidate(categoriesProvider);
          ref.invalidate(myListingsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search Bar ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => context.go('/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search for phones, clothes, textbooks...',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 15,
                                  ),
                            ),
                          ),
                          const Icon(Icons.tune, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Categories ──
            if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 90,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _CategoryPill(
                        label: 'All',
                        icon: Icons.grid_view_rounded,
                        isSelected: _selectedCategoryId == null,
                        onTap: () => setState(() => _selectedCategoryId = null),
                      ),
                      const SizedBox(width: 12),
                      for (final category in categories)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _CategoryPill(
                            label: category.displayName,
                            icon: _iconForCategory(category.displayName),
                            isSelected: _selectedCategoryId == category.id,
                            onTap: () => setState(() => _selectedCategoryId = category.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            // ── Promo Banner ──
            if (_showPromoBanner)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Buy. Sell. Connect.',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A trusted marketplace\nfor our campus community.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => context.push('/sell'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                minimumSize: const Size(120, 40),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Sell an item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                  SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_rounded, size: 16),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          top: -8,
                          right: -8,
                          child: IconButton(
                            icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.6), size: 20),
                            onPressed: () => setState(() => _showPromoBanner = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Latest Listings Header ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Latest Listings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: const Text('See all'),
                    ),
                  ],
                ),
              ),
            ),

            // ── Listings Grid ──
            feedAsync.when(
              data: (products) {
                final filteredProducts = _filterProducts(products);

                if (products.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No listings yet', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                }

                if (filteredProducts.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Text('No listings in this category', style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisExtent: 245,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => ProductCard(product: filteredProducts[index]),
                      childCount: filteredProducts.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(child: Text(ErrorMapper.toAppException(error).message)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected ? AppColors.primary : AppColors.surface;
    final fgColor = isSelected ? Colors.white : AppColors.textPrimary;
    final borderColor = isSelected ? AppColors.primary : AppColors.border;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
