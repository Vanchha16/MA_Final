import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/catalog_service.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/product_feed.dart';
import '../../widgets/round_icon_button.dart';
import '../../widgets/shop_search_bar.dart';
import '../../widgets/sort_header.dart';
import '../catalog/product_list_screen.dart';
import 'widgets/filter_sheet.dart';
import 'widgets/promo_carousel.dart';
import 'widgets/series_tabs.dart';

/// Home tab (Figma: Home C - Series Tabs Feed): brand bar with bell and
/// cart, search with filters, series tabs, promo banner slider and a product
/// grid that loads more as you scroll. Pull down to refresh.
class HomeScreen extends StatefulWidget {
  static const pageSize = 10;

  /// Injected in tests; the real API otherwise.
  final CatalogService? catalogService;

  /// Switches the shell to the Cart tab.
  final VoidCallback? onOpenCart;

  const HomeScreen({super.key, this.catalogService, this.onOpenCart});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  final _search = TextEditingController();
  Timer? _debounce;

  List<Series> _series = [];
  List<Category> _categories = [];
  List<String> _brands = [];

  ProductQuery _query = const ProductQuery();
  late final _feed = ProductFeed((page) => _catalog.products(_query, page: page, perPage: HomeScreen.pageSize));

  @override
  void initState() {
    super.initState();
    _loadExtras();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _feed.dispose();
    super.dispose();
  }

  /// Series tabs and categories (filter sheet, banner links).
  /// Each is optional: the screen still works if one fails.
  Future<void> _loadExtras() async {
    Future<T?> safe<T>(Future<T> f) => f.then<T?>((v) => v).catchError((_) => null);
    final (series, categories, brands) = await (safe(_catalog.series()), safe(_catalog.categories()), safe(_catalog.brands())).wait;
    if (!mounted) return;
    setState(() {
      _series = series ?? _series;
      _categories = categories ?? _categories;
      _brands = brands ?? _brands;
    });
  }

  void _setQuery(ProductQuery query) {
    setState(() => _query = query);
    _feed.refresh();
  }

  void _onSearchChanged(String text) {
    setState(() {}); // shows/hides the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _submitSearch(text));
  }

  void _submitSearch(String text) {
    _debounce?.cancel();
    if (text.trim() != _query.q) _setQuery(_query.copyWith(q: text.trim()));
  }

  void _clearAll() {
    _search.clear();
    _setQuery(_query.cleared());
  }

  Future<void> _openFilters() async {
    if (_categories.isEmpty) await _loadExtras();
    if (!mounted) return;
    final result = await FilterSheet.show(context, query: _query, categories: _categories, brands: _brands);
    if (result != null) _setQuery(result);
  }

  Future<void> _refresh() async {
    await Future.wait([_feed.reload(), _loadExtras(), context.read<ShopProvider>().refresh()]);
  }

  /// Banner tap: show that category's products, or the slide's info.
  Future<void> _openPromo(PromoSlide slide) async {
    if (slide.categorySlug == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(slide.info ?? slide.title), behavior: SnackBarBehavior.floating));
      return;
    }
    if (_categories.isEmpty) await _loadExtras();
    final category = _categories.where((c) => c.slug == slide.categorySlug).firstOrNull;
    if (category == null || !mounted) return;
    _search.clear();
    _setQuery(_query.cleared().copyWith(categoryId: () => category.id));
  }

  String get _title {
    if (_query.q.isNotEmpty) return 'Results for "${_query.q}"';
    if (_query.seriesId != null) {
      return _series.where((s) => s.id == _query.seriesId).map((s) => s.name).firstOrNull ?? 'Series';
    }
    final onlyCategory = _query.categoryId != null && _query.activeFilterCount == 1;
    if (onlyCategory) {
      return _categories.where((c) => c.id == _query.categoryId).map((c) => c.name).firstOrNull ?? 'Filtered results';
    }
    if (_query.activeFilterCount > 0) return 'Filtered results';
    return 'Popular now';
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = !_query.isFiltered;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    children: [
                      _BrandBar(onOpenCart: widget.onOpenCart),
                      const SizedBox(height: 18),
                      ShopSearchBar(
                        controller: _search,
                        filterCount: _query.activeFilterCount,
                        onChanged: _onSearchChanged,
                        onSubmitted: _submitSearch,
                        onClear: () {
                          _search.clear();
                          _submitSearch('');
                          setState(() {});
                        },
                        onFilter: _openFilters,
                      ),
                    ],
                  ),
                ),
              ),
              if (_series.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 18),
                  sliver: SliverToBoxAdapter(
                    child: SeriesTabs(
                      series: _series,
                      selectedId: _query.seriesId,
                      onSelected: (id) => _setQuery(_query.copyWith(seriesId: () => id)),
                    ),
                  ),
                ),
              if (showBanner)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: PromoCarousel(onTap: _openPromo),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
                sliver: SliverToBoxAdapter(
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _feed.total,
                    builder: (_, total, _) => SortHeader(
                      title: _title,
                      subtitle: _query.isFiltered && total != null ? '$total ${total == 1 ? 'item' : 'items'}' : null,
                      sort: _query.sort,
                      onSort: (s) => _setQuery(_query.copyWith(sort: s)),
                      actions: [
                        if (!_query.isFiltered)
                          TextButton(
                            key: const Key('home_see_all'),
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ProductListScreen(
                                title: 'All products',
                                query: ProductQuery(sort: _query.sort),
                                catalogService: widget.catalogService,
                              ),
                            )),
                            child: const Text('See all'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ProductFeedGrid(feed: _feed, catalogService: widget.catalogService, onClear: _clearAll),
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandBar extends StatelessWidget {
  final VoidCallback? onOpenCart;

  const _BrandBar({this.onOpenCart});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final firstName = user?.fullName.split(' ').first;

    return Row(
      children: [
        Image.asset('assets/logo_centered.png', width: 40, height: 40, semanticLabel: 'Anime World Shop logo'),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anime World',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: dark ? scheme.primary : AppTheme.primaryDark)),
              Text(
                firstName == null ? 'Hi there, welcome' : 'Hi $firstName, welcome back',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        RoundIconButton(
          icon: Icons.notifications_none_rounded,
          tooltip: 'Notifications',
          onPressed: () => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('You have no new notifications'), behavior: SnackBarBehavior.floating)),
        ),
        const SizedBox(width: 10),
        CartButton(onPressed: onOpenCart),
      ],
    );
  }
}

