import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../../helpers/format.dart';
import '../../models/catalog.dart';
import '../../services/catalog_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/product_feed.dart';
import '../../widgets/sort_header.dart';
import '../home/widgets/filter_sheet.dart';

/// Products of one category, series, search or "All products" (screen 11,
/// Figma: 10 Product List): grid or list view, sort, filters on
/// top of the starting query shown as removable chips, and paging.
class ProductListScreen extends StatefulWidget {
  final String title;

  /// Starting query, e.g. `ProductQuery(categoryId: 1)`. "Clear filters" goes back to it.
  final ProductQuery query;
  final CatalogService? catalogService;

  const ProductListScreen({super.key, required this.title, required this.query, this.catalogService});

  /// Remembers grid or list view on this device.
  static const viewPrefKey = 'product_list_view';

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const pageSize = 10;

  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  late ProductQuery _query = widget.query;
  late final _feed = ProductFeed((page) => _catalog.products(_query, page: page, perPage: pageSize));
  List<Category> _categories = [];
  List<Series> _series = [];
  List<String> _brands = [];
  bool _listView = false;

  @override
  void initState() {
    super.initState();
    _loadViewPref();
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  Future<void> _loadViewPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getBool(ProductListScreen.viewPrefKey) ?? false;
      if (mounted && list != _listView) setState(() => _listView = list);
    } catch (_) {
      // Grid view is fine when the setting cannot be read
    }
  }

  Future<void> _toggleView() async {
    setState(() => _listView = !_listView);
    try {
      (await SharedPreferences.getInstance()).setBool(ProductListScreen.viewPrefKey, _listView);
    } catch (_) {
      // Only a convenience
    }
  }

  void _setQuery(ProductQuery query) {
    setState(() => _query = query);
    _feed.refresh();
  }

  Future<void> _openFilters() async {
    try {
      if (_categories.isEmpty || _brands.isEmpty) {
        final results = await Future.wait([_catalog.categories(), _catalog.series(), _catalog.brands()]);
        _categories = results[0] as List<Category>;
        _series = results[1] as List<Series>;
        _brands = results[2] as List<String>;
      }
    } catch (_) {
      // The sheet still works without category and brand chips
    }
    if (!mounted) return;
    final result = await FilterSheet.show(
      context,
      query: _query,
      categories: _categories,
      series: _series,
      brands: _brands,
      countResults: _catalog.count,
    );
    if (result != null) _setQuery(result);
  }

  /// Filters chosen on this screen, on top of the screen's own category/series/search.
  List<_ActiveFilter> get _activeFilters {
    final base = widget.query;
    final q = _query;
    final filters = <_ActiveFilter>[];
    if (q.categoryId != null && q.categoryId != base.categoryId) {
      final name = _categories.where((c) => c.id == q.categoryId).map((c) => c.name).firstOrNull ?? 'Category';
      filters.add(_ActiveFilter('category', name, q.copyWith(categoryId: () => base.categoryId)));
    }
    if (q.seriesId != null && q.seriesId != base.seriesId) {
      final name = _series.where((s) => s.id == q.seriesId).map((s) => s.name).firstOrNull ?? 'Series';
      filters.add(_ActiveFilter('series', name, q.copyWith(seriesId: () => base.seriesId)));
    }
    for (final b in q.brands.where((b) => !base.brands.contains(b))) {
      filters.add(_ActiveFilter('brand_$b', b, q.copyWith(brands: q.brands.where((x) => x != b).toList())));
    }
    if ((q.minPrice != null || q.maxPrice != null) && (q.minPrice != base.minPrice || q.maxPrice != base.maxPrice)) {
      final label = q.minPrice != null && q.maxPrice != null
          ? '${formatPrice(q.minPrice!)} - ${formatPrice(q.maxPrice!)}'
          : q.maxPrice != null
              ? 'Under ${formatPrice(q.maxPrice!)}'
              : '${formatPrice(q.minPrice!)}+';
      filters.add(_ActiveFilter('price', label, q.copyWith(minPrice: () => base.minPrice, maxPrice: () => base.maxPrice)));
    }
    if (q.inStockOnly && !base.inStockOnly) {
      filters.add(_ActiveFilter('stock', 'In stock', q.copyWith(inStockOnly: false)));
    }
    return filters;
  }

  void _clearFilters() => _setQuery(widget.query.copyWith(sort: _query.sort));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filters = _activeFilters;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _feed.reload,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      CircleBackButton(onPressed: () => Navigator.of(context).maybePop()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Badge(
                        isLabelVisible: filters.isNotEmpty,
                        label: Text('${filters.length}'),
                        backgroundColor: AppTheme.coral,
                        child: IconButton.filled(
                          key: const Key('list_filter'),
                          tooltip: 'Filters',
                          onPressed: _openFilters,
                          style: IconButton.styleFrom(
                            backgroundColor: AppTheme.primaryDark,
                            foregroundColor: Colors.white,
                            fixedSize: const Size(48, 48),
                          ),
                          icon: const Icon(Icons.tune_rounded),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _feed.total,
                    builder: (_, total, _) => SortHeader(
                      title: total == null ? 'Products' : '$total ${total == 1 ? 'product' : 'products'}',
                      sort: _query.sort,
                      onSort: (s) => _setQuery(_query.copyWith(sort: s)),
                      actions: [
                        IconButton(
                          key: const Key('list_view_toggle'),
                          tooltip: _listView ? 'Show as grid' : 'Show as list',
                          onPressed: _toggleView,
                          icon: Icon(_listView ? Icons.grid_view_rounded : Icons.view_agenda_outlined, color: scheme.onSurfaceVariant),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
              ),
              if (filters.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final f in filters)
                          InputChip(
                            key: Key('active_${f.id}'),
                            label: Text(f.label),
                            onDeleted: () => _setQuery(f.without),
                            deleteButtonTooltipMessage: 'Remove ${f.label}',
                            labelStyle: TextStyle(fontWeight: FontWeight.w600, color: scheme.primary),
                            backgroundColor: scheme.primary.withValues(alpha: 0.08),
                            side: BorderSide.none,
                            shape: const StadiumBorder(),
                          ),
                        if (filters.length > 1)
                          TextButton(key: const Key('active_clear_all'), onPressed: _clearFilters, child: const Text('Clear all')),
                      ],
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),
              ProductFeedGrid(
                feed: _feed,
                catalogService: widget.catalogService,
                listView: _listView,
                onClear: filters.isNotEmpty ? _clearFilters : null,
                emptyMessage: filters.isNotEmpty ? 'Try removing a filter.' : 'Nothing here yet. Check back soon!',
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveFilter {
  final String id;
  final String label;

  /// The query with this filter removed.
  final ProductQuery without;

  const _ActiveFilter(this.id, this.label, this.without);
}
