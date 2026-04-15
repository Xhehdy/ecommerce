import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/colors.dart';
import '../../application/marketplace_providers.dart';
import '../../data/models/category_model.dart';
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
    final filters = _filters.copyWith(query: _queryController.text.trim());
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final recentSearchesAsync = ref.watch(recentSearchesProvider);
    final categories = categoriesAsync.asData?.value ?? const <Category>[];
    final categoriesById = {
      for (final category in categories) category.id: category.displayName,
    };
    final searchResultsAsync = _hasSubmittedSearch
        ? ref.watch(searchResultsProvider(_filters))
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      bottomNavigationBar: const MarketplaceBottomNavBar(
        currentTab: MarketplaceTab.search,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Find what you need fast',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Search by keyword, then tighten the results with price and category filters.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _queryController,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _applyCurrentQuery(),
                          decoration: const InputDecoration(
                            labelText: 'Search products',
                            hintText: 'Try shoes, phone, textbook...',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      categoriesAsync.when(
                        data: (categories) => IconButton.filledTonal(
                          onPressed: () => _openFilters(categories),
                          icon: const Icon(Icons.tune),
                        ),
                        loading: () => const SizedBox(
                          height: 40,
                          width: 40,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, _) => IconButton.filledTonal(
                          onPressed: null,
                          icon: const Icon(Icons.tune),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_filters.query.trim().isNotEmpty)
                        Chip(label: Text('Query: ${_filters.query.trim()}')),
                      if (_filters.categoryId != null)
                        Chip(
                          label: Text(
                            categoriesById[_filters.categoryId] ??
                                'Category #${_filters.categoryId}',
                          ),
                        ),
                      if (_filters.minPrice != null)
                        Chip(
                          label: Text(
                            'Min \$${_filters.minPrice!.toStringAsFixed(2)}',
                          ),
                        ),
                      if (_filters.maxPrice != null)
                        Chip(
                          label: Text(
                            'Max \$${_filters.maxPrice!.toStringAsFixed(2)}',
                          ),
                        ),
                      if (_filters.sortOption != ProductSortOption.newest)
                        Chip(label: Text(_filters.sortOption.label)),
                      if (_filters.hasActiveFilters)
                        ActionChip(
                          label: const Text('Clear'),
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
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _applyCurrentQuery,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: !_hasSubmittedSearch
                ? recentSearchesAsync.when(
                    data: (recentSearches) => ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (recentSearches.isNotEmpty) ...[
                          Text(
                            'Recent Searches',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          ...recentSearches.map(
                            (recentSearch) => Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ListTile(
                                title: Text(
                                  recentSearch.query.isEmpty
                                      ? 'Filtered search'
                                      : recentSearch.query,
                                ),
                                subtitle: Text(
                                  recentSearch.categoryId == null
                                      ? recentSearch.sortOption.label
                                      : '${categoriesById[recentSearch.categoryId] ?? 'Category'} • ${recentSearch.sortOption.label}',
                                ),
                                trailing: const Icon(Icons.history),
                                onTap: () => _applyRecentSearch(recentSearch),
                              ),
                            ),
                          ),
                        ] else
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'No recent searches yet',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Start with a keyword or open filters to narrow the marketplace.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Unable to load recent searches: $error'),
                      ),
                    ),
                  )
                : searchResultsAsync!.when(
                    data: (products) {
                      if (products.isEmpty) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.search_off_outlined,
                                    size: 48,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results matched your search.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Try a different keyword or widen your price range.',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              mainAxisExtent: 290,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 18,
                            ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          return ProductCard(product: products[index]);
                        },
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (error, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Unable to search products: $error'),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

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
                    decoration: const InputDecoration(labelText: 'Min Price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Max Price'),
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
                if (value == null) {
                  return;
                }

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
