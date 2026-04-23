import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/colors.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/search_models.dart';
import '../../data/repositories/marketplace_repository.dart';
import '../widgets/marketplace_navigation.dart';
import '../widgets/product_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _queryController = TextEditingController();

  ProductSearchFilters _filters = const ProductSearchFilters();
  bool _hasSubmittedSearch = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(ProductSearchFilters filters) async {
    setState(() {
      _filters = filters;
      _hasSubmittedSearch = true;
    });

    await ref.read(marketplaceRepositoryProvider).saveRecentSearch(filters);
    ref.invalidate(recentSearchesProvider);
  }

  Future<void> _applyCurrentQuery() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _hasSubmittedSearch = false;
        _filters = const ProductSearchFilters();
      });
      return;
    }
    final filters = _filters.copyWith(query: query);
    await _runSearch(filters);
  }

  Future<void> _openFilters(List<Category> categories) async {
    final nextFilters = await showModalBottomSheet<ProductSearchFilters>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SearchFilterSheet(
        categories: categories,
        initialFilters: _filters.copyWith(query: _queryController.text.trim()),
      ),
    );

    if (nextFilters == null) {
      return;
    }

    _queryController.text = nextFilters.query;
    await _runSearch(nextFilters);
  }

  Future<void> _applyRecentSearch(RecentSearch recentSearch) async {
    final filters = recentSearch.toFilters();
    _queryController.text = filters.query;
    await _runSearch(filters);
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
    final recentSearchesAsync = ref.watch(recentSearchesProvider);
    final suggestedAsync = ref.watch(homeFeedProvider); // Using home feed for suggested
    final categories = categoriesAsync.asData?.value ?? const <Category>[];

    final searchResultsAsync = _hasSubmittedSearch
        ? ref.watch(searchResultsProvider(_filters))
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search', style: TextStyle(fontWeight: FontWeight.w800)),
        centerTitle: false,
      ),
      bottomNavigationBar: const MarketplaceBottomNavBar(
        currentTab: MarketplaceTab.search,
      ),
      body: Column(
        children: [
          // ── Search Input ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applyCurrentQuery(),
              decoration: InputDecoration(
                hintText: 'Search for anything...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.tune, color: AppColors.textSecondary),
                  onPressed: () => _openFilters(categories),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // ── Active Filters Chips ──
          if (_hasSubmittedSearch && _filters.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (_filters.categoryId != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text(
                            categories.firstWhere((c) => c.id == _filters.categoryId, orElse: () => const Category(id: 0, slug: '', name: 'Category')).displayName,
                          ),
                          onDeleted: () {
                            _runSearch(_filters.copyWith(categoryId: null));
                          },
                        ),
                      ),
                    if (_filters.minPrice != null || _filters.maxPrice != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('Price filtered'),
                          onDeleted: () {
                            _runSearch(_filters.copyWith(minPrice: null, maxPrice: null));
                          },
                        ),
                      ),
                    ActionChip(
                      label: const Text('Clear all'),
                      onPressed: () {
                        setState(() {
                          _filters = const ProductSearchFilters();
                          _queryController.clear();
                          _hasSubmittedSearch = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

          // ── Main Content Area ──
          Expanded(
            child: !_hasSubmittedSearch
                ? CustomScrollView(
                    slivers: [
                      // ── Recent Searches ──
                      recentSearchesAsync.when(
                        data: (recentSearches) {
                          if (recentSearches.isEmpty) return const SliverToBoxAdapter();
                          return SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Recent searches', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                      TextButton(
                                        onPressed: () async {
                                          await ref.read(marketplaceRepositoryProvider).clearRecentSearches();
                                          ref.invalidate(recentSearchesProvider);
                                        },
                                        style: TextButton.styleFrom(
                                          foregroundColor: AppColors.primary,
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                        ),
                                        child: const Text('Clear all'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: recentSearches.map((rs) {
                                      return ActionChip(
                                        label: Text(rs.query.isEmpty ? 'Filtered' : rs.query),
                                        onPressed: () => _applyRecentSearch(rs),
                                        backgroundColor: AppColors.surface,
                                        side: const BorderSide(color: AppColors.border),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loading: () => const SliverToBoxAdapter(),
                        error: (_, __) => const SliverToBoxAdapter(),
                      ),

                      // ── Popular Categories ──
                      if (categories.isNotEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Popular categories', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 16),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    mainAxisExtent: 42,
                                  ),
                                  itemCount: categories.length,
                                  itemBuilder: (context, index) {
                                    final cat = categories[index];
                                    return OutlinedButton.icon(
                                      onPressed: () {
                                        _runSearch(ProductSearchFilters(categoryId: cat.id));
                                      },
                                      icon: Icon(_iconForCategory(cat.displayName), size: 18, color: AppColors.textSecondary),
                                      label: Text(
                                        cat.displayName,
                                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        alignment: Alignment.centerLeft,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        side: const BorderSide(color: AppColors.border),
                                        backgroundColor: AppColors.surface,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                      // ── Suggested for you ──
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text('Suggested for you', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      suggestedAsync.when(
                        data: (products) {
                          if (products.isEmpty) return const SliverToBoxAdapter();
                          // Show a list view of products (horizontal tile layout)
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final product = products[index];
                                return _SuggestedProductTile(product: product);
                              },
                              childCount: products.take(5).length, // Just show top 5 suggested
                            ),
                          );
                        },
                        loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => const SliverToBoxAdapter(),
                      ),
                    ],
                  )
                : searchResultsAsync!.when(
                    data: (products) {
                      if (products.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.search_off_outlined, size: 64, color: AppColors.border),
                              const SizedBox(height: 16),
                              Text('No results found', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              const Text('Try adjusting your search or filters.', style: TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 240,
                          mainAxisExtent: 245,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return ProductCard(product: products[index]);
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(child: Text(ErrorMapper.toAppException(error).message)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedProductTile extends StatelessWidget {
  final Product product;

  const _SuggestedProductTile({required this.product});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/product/${product.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                image: product.images.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(product.images.first.imageUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: product.images.isEmpty
                  ? const Icon(Icons.image_outlined, color: AppColors.border)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatNaira(product.price),
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.location ?? 'Main Campus',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.favorite_border_rounded, color: AppColors.textSecondary),
              onPressed: () {
                // TODO: toggle favorite
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Reusing the same filter sheet logic but keeping the UI styling clean
class _SearchFilterSheet extends StatefulWidget {
  final List<Category> categories;
  final ProductSearchFilters initialFilters;

  const _SearchFilterSheet({
    required this.categories,
    required this.initialFilters,
  });

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late final TextEditingController _minPriceController;
  late final TextEditingController _maxPriceController;

  int? _selectedCategoryId;
  ProductSortOption _selectedSortOption = ProductSortOption.newest;
  bool _availableOnly = true;

  @override
  void initState() {
    super.initState();
    _minPriceController = TextEditingController(
      text: widget.initialFilters.minPrice?.toStringAsFixed(2) ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialFilters.maxPrice?.toStringAsFixed(2) ?? '',
    );
    _selectedCategoryId = widget.initialFilters.categoryId;
    _selectedSortOption = widget.initialFilters.sortOption;
    _availableOnly = widget.initialFilters.availableOnly;
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _selectedCategoryId = null;
      _selectedSortOption = ProductSortOption.newest;
      _availableOnly = true;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      widget.initialFilters.copyWith(
        categoryId: _selectedCategoryId,
        minPrice: _minPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_minPriceController.text.trim()),
        maxPrice: _maxPriceController.text.trim().isEmpty
            ? null
            : double.tryParse(_maxPriceController.text.trim()),
        sortOption: _selectedSortOption,
        availableOnly: _availableOnly,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            DropdownButtonFormField<int?>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...widget.categories.map(
                  (category) => DropdownMenuItem<int?>(
                    value: category.id,
                    child: Text(category.displayName),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _selectedCategoryId = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Min Price (₦)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Max Price (₦)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ProductSortOption>(
              initialValue: _selectedSortOption,
              decoration: const InputDecoration(labelText: 'Sort By'),
              items: ProductSortOption.values
                  .map(
                    (option) => DropdownMenuItem<ProductSortOption>(
                      value: option,
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedSortOption = value);
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              value: _availableOnly,
              contentPadding: EdgeInsets.zero,
              title: const Text('Available items only'),
              onChanged: (value) => setState(() => _availableOnly = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('RESET'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _apply,
                    child: const Text('APPLY'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
