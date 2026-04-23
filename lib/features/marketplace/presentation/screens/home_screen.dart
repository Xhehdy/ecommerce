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
  late final ScrollController _scrollController;
  bool _showCollapsedTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(authControllerProvider).ensureCurrentUserProfile();
        ref.invalidate(profileProvider);
      } catch (error) {
        if (!mounted) {
          return;
        }

        AppSnackbars.showError(context, error);
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final shouldShowCollapsedTitle = _scrollController.offset > 36;
    if (shouldShowCollapsedTitle == _showCollapsedTitle) {
      return;
    }

    setState(() {
      _showCollapsedTitle = shouldShowCollapsedTitle;
    });
  }

  String? _firstNameFromProfile(String? rawValue) {
    final normalizedValue = rawValue?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return null;
    }

    return normalizedValue.split(' ').first;
  }

  String _categoryLabelFor(List<Category> categories, int? categoryId) {
    if (categoryId == null) {
      return 'All categories';
    }

    for (final category in categories) {
      if (category.id == categoryId) {
        return category.displayName;
      }
    }

    return 'Category';
  }

  List<Product> _filterProducts(List<Product> products) {
    if (_selectedCategoryId == null) {
      return products;
    }

    return products
        .where((product) => product.categoryId == _selectedCategoryId)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final feedAsync = ref.watch(homeFeedProvider);
    final profileAsync = ref.watch(profileProvider);
    final profile = profileAsync.asData?.value;
    final categories = categoriesAsync.asData?.value ?? const <Category>[];
    final firstName = _firstNameFromProfile(profile?.fullName);
    final welcomeTitle = firstName == null
        ? 'Welcome back'
        : 'Welcome back, $firstName';
    final totalLiveListings = feedAsync.asData?.value.length ?? 0;
    final selectedCategoryLabel = _categoryLabelFor(
      categories,
      _selectedCategoryId,
    );

    return Scaffold(
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
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 108,
              collapsedHeight: 72,
              automaticallyImplyLeading: false,
              centerTitle: true,
              backgroundColor: AppColors.background,
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showCollapsedTitle ? 1 : 0,
                child: const Text(
                  'ATELIER.',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    tooltip: 'Saved items',
                    icon: const Icon(Icons.favorite_border_rounded),
                    onPressed: () => context.push('/favorites'),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                titlePadding: const EdgeInsets.only(bottom: 18),
                title: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: _showCollapsedTitle ? 0 : 1,
                  child: const Text(
                    'ATELIER.',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Campus marketplace',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        welcomeTitle,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w800,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        profile?.faculty?.trim().isNotEmpty == true
                            ? '${profile!.faculty} marketplace finds, ready for quick campus meetups.'
                            : 'Fresh campus finds, ready for quick meetups and safer student-to-student selling.',
                        style: TextStyle(
                          color: Colors.white70,
                          height: 1.4,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _HeroPill(
                            label: '$totalLiveListings live listings',
                            icon: Icons.storefront_outlined,
                          ),
                          _HeroPill(
                            label: selectedCategoryLabel,
                            icon: Icons.category_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _QuickActionButton(
                            label: 'Sell',
                            icon: Icons.add_circle_outline,
                            onTap: () => context.push('/sell'),
                          ),
                          _QuickActionButton(
                            label: 'Orders',
                            icon: Icons.receipt_long_outlined,
                            onTap: () => context.go('/orders'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                child: Material(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => context.go('/search'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Search for phones, clothes, textbooks...',
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(fontSize: 15),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'Open',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (categoriesAsync.hasError)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _InlineMessageCard(
                    icon: Icons.category_outlined,
                    title: 'Categories are unavailable right now',
                    message:
                        'You can still browse listings or use search while category filters catch up.',
                  ),
                ),
              )
            else if (categories.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Browse by Category',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap a category to narrow down the home feed.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/search'),
                            child: const Text('Open Search'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 10),
                              child: FilterChip(
                                label: const Text('All'),
                                selected: _selectedCategoryId == null,
                                onSelected: (_) {
                                  setState(() => _selectedCategoryId = null);
                                },
                              ),
                            ),
                            for (final category in categories)
                              Padding(
                                padding: const EdgeInsets.only(right: 10),
                                child: FilterChip(
                                  label: Text(category.displayName),
                                  selected: _selectedCategoryId == category.id,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedCategoryId =
                                          _selectedCategoryId == category.id
                                          ? null
                                          : category.id;
                                    });
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: feedAsync.when(
                data: (products) {
                  final filteredProducts = _filterProducts(products);
                  final subtitle = products.isEmpty
                      ? 'Start with one great listing and build the marketplace from there.'
                      : _selectedCategoryId == null
                      ? '${products.length} listings ready for quick campus deals.'
                      : '${filteredProducts.length} listing${filteredProducts.length == 1 ? '' : 's'} in $selectedCategoryLabel.';

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Latest Listings',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        if (_selectedCategoryId != null)
                          TextButton(
                            onPressed: () {
                              setState(() => _selectedCategoryId = null);
                            },
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ),
            feedAsync.when(
              data: (products) {
                final filteredProducts = _filterProducts(products);

                if (products.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _EmptyFeedCard(
                        title: 'No listings yet',
                        message:
                            'Start the marketplace demo by posting the first item.',
                        buttonLabel: 'Create First Listing',
                        onPressed: () => context.push('/sell'),
                      ),
                    ),
                  );
                }

                if (filteredProducts.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _EmptyFeedCard(
                        title: 'No listings in $selectedCategoryLabel',
                        message:
                            'Try another category or clear the filter to see everything available.',
                        buttonLabel: 'Show All Listings',
                        onPressed: () {
                          setState(() => _selectedCategoryId = null);
                        },
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 290,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 18,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      return ProductCard(product: filteredProducts[index]);
                    }, childCount: filteredProducts.length),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(ErrorMapper.toAppException(error).message),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.white, size: 16),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeroPill({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeedCard extends StatelessWidget {
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  const _EmptyFeedCard({
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 34,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          ElevatedButton(
            onPressed: onPressed,
            child: Text(buttonLabel.toUpperCase()),
          ),
        ],
      ),
    );
  }
}

class _InlineMessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _InlineMessageCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
