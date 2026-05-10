import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/ui/snackbars.dart';
import '../../../../core/ui/shimmer.dart';
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
    if (lower.contains('home') || lower.contains('hostel')) {
      return Icons.chair_outlined;
    }
    if (lower.contains('sport')) return Icons.sports_basketball_outlined;
    return Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final feedAsync = ref.watch(homeFeedProvider);
    final categories = categoriesAsync.asData?.value ?? const <Category>[];

    return Scaffold(
      bottomNavigationBar: const MarketplaceBottomNavBar(
        currentTab: MarketplaceTab.home,
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeFeedProvider);
            ref.invalidate(categoriesProvider);
            ref.invalidate(myListingsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                title: const Text(
                  'ATELIER.',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border_rounded),
                    onPressed: () => context.push('/saved'),
                  ),
                ],
                automaticallyImplyLeading: false,
                backgroundColor: AppColors.background,
                foregroundColor: AppColors.textPrimary,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                pinned: false,
                floating: false,
              ),

              // ── Sticky Search Bar ──
              SliverPersistentHeader(
                pinned: true,
                delegate: _SearchHeaderDelegate(
                  onTap: () => context.go('/search'),
                ),
              ),

              // ── Categories ──
              if (categories.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 90,
                    child: ShaderMask(
                      shaderCallback: (bounds) {
                        return const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.transparent,
                            Colors.white,
                            Colors.white,
                            Colors.transparent,
                          ],
                          stops: [0, 0.06, 0.94, 1],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          _CategoryPill(
                            label: 'All',
                            icon: Icons.grid_view_rounded,
                            isSelected: _selectedCategoryId == null,
                            onTap: () =>
                                setState(() => _selectedCategoryId = null),
                          ),
                          const SizedBox(width: 12),
                          for (final category in categories)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: _CategoryPill(
                                label: category.displayName,
                                icon: _iconForCategory(category.displayName),
                                isSelected: _selectedCategoryId == category.id,
                                onTap: () => setState(
                                  () => _selectedCategoryId = category.id,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Promo Banner ──
              SliverToBoxAdapter(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  reverseDuration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) {
                    return SizeTransition(
                      sizeFactor: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      ),
                      axisAlignment: -1,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: _showPromoBanner
                      ? Padding(
                          key: const ValueKey('promo-banner'),
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
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
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'A trusted marketplace\nfor our campus community.',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    ElevatedButton(
                                      onPressed: () => context.push('/sell'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: AppColors.primaryDark,
                                        minimumSize: const Size(120, 40),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Sell an item',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          SizedBox(width: 4),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Positioned(
                                  top: -10,
                                  right: -10,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      size: 20,
                                    ),
                                    onPressed: () => setState(
                                      () => _showPromoBanner = false,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('promo-banner-gap'),
                          height: 12,
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/search'),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
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
                      child: _HomeEmptyState(
                        title: 'No listings yet',
                        message:
                            'Be the first to post something useful for campus buyers.',
                        actionLabel: 'Create listing',
                        onPressed: () => context.push('/sell'),
                      ),
                    );
                  }

                  if (filteredProducts.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: _HomeEmptyState(
                        title: 'No listings in this category',
                        message:
                            'Try all listings or search for a specific item.',
                        actionLabel: 'Clear category',
                        onPressed: () =>
                            setState(() => _selectedCategoryId = null),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 240,
                            mainAxisExtent: 245,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 16,
                          ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            ProductCard(product: filteredProducts[index]),
                        childCount: filteredProducts.length,
                      ),
                    ),
                  );
                },
                loading: () => SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 245,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => const ProductCardShimmer(),
                      childCount: 6,
                    ),
                  ),
                ),
                error: (error, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: _HomeErrorState(
                    message: ErrorMapper.toAppException(error).message,
                    onRetry: () => ref.invalidate(homeFeedProvider),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  final VoidCallback onTap;

  const _SearchHeaderDelegate({required this.onTap});

  @override
  double get minExtent => 72;

  @override
  double get maxExtent => 72;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: overlapsContent
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: _HomeSearchButton(onTap: onTap),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _SearchHeaderDelegate oldDelegate) {
    return oldDelegate.onTap != onTap;
  }
}

class _HomeSearchButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HomeSearchButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.tune, color: AppColors.textSecondary),
            ],
          ),
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
        width: 80,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fgColor, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 11,
                height: 1.1,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onPressed;

  const _HomeEmptyState({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 44,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              ElevatedButton(onPressed: onPressed, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _HomeErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              'Unable to load listings',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
