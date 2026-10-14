import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../services/catalog_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/product_feed.dart';
import '../../widgets/sort_header.dart';
import '../home/widgets/filter_sheet.dart';

/// Products of one category, series or search, with sort, filters and
/// paging (BUILD_PROMPT screen 11: Product List).
class ProductListScreen extends StatefulWidget {
  final String title;

  /// Starting query, e.g. `ProductQuery(categoryId: 1)`. "Clear filters" goes back to it.
  final ProductQuery query;
  final CatalogService? catalogService;

  const ProductListScreen({super.key, required this.title, required this.query, this.catalogService});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  static const pageSize = 10;

  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  late ProductQuery _query = widget.query;
  late final _feed = ProductFeed((page) => _catalog.products(_query, page: page, perPage: pageSize));
  List<Category> _categories = [];

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  void _setQuery(ProductQuery query) {
    setState(() => _query = query);
    _feed.refresh();
  }

  /// Filters chosen here, on top of the screen's own category/series/search.
  int get _extraFilters => _query.activeFilterCount - widget.query.activeFilterCount;

  Future<void> _openFilters() async {
    if (_categories.isEmpty) {
      try {
        _categories = await _catalog.categories();
      } catch (_) {
        // The sheet still works without the category chips
      }
    }
    if (!mounted) return;
    final result = await FilterSheet.show(context, query: _query, categories: _categories);
    if (result != null) _setQuery(result);
  }

  @override
  Widget build(BuildContext context) {
    final filterCount = _extraFilters.clamp(0, 9);
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
                        isLabelVisible: filterCount > 0,
                        label: Text('$filterCount'),
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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
                sliver: SliverToBoxAdapter(
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _feed.total,
                    builder: (_, total, _) => SortHeader(
                      title: total == null ? 'Products' : '$total ${total == 1 ? 'product' : 'products'}',
                      sort: _query.sort,
                      onSort: (s) => _setQuery(_query.copyWith(sort: s)),
                    ),
                  ),
                ),
              ),
              ProductFeedGrid(
                feed: _feed,
                onClear: _extraFilters > 0 ? () => _setQuery(widget.query.copyWith(sort: _query.sort)) : null,
                emptyMessage: _extraFilters > 0 ? 'Try clearing the filters.' : 'Nothing here yet. Check back soon!',
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}
