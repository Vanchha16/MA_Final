import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/catalog_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/round_icon_button.dart';
import '../shop/shop_actions.dart';
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
  final _scroll = ScrollController();
  Timer? _debounce;

  List<Series> _series = [];
  List<Category> _categories = [];

  ProductQuery _query = const ProductQuery();
  List<Product> _items = [];
  int _page = 0;
  int _total = 0;
  bool _hasMore = false;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _request = 0; // ignores answers to older requests

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadExtras();
    _loadProducts();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Series tabs and categories (filter sheet, banner links).
  /// Each is optional: the screen still works if one fails.
  Future<void> _loadExtras() async {
    Future<T?> safe<T>(Future<T> f) => f.then<T?>((v) => v).catchError((_) => null);
    final (series, categories) = await (safe(_catalog.series()), safe(_catalog.categories())).wait;
    if (!mounted) return;
    setState(() {
      _series = series ?? _series;
      _categories = categories ?? _categories;
    });
  }

  Future<void> _loadProducts({bool more = false}) async {
    final id = ++_request;
    final page = more ? _page + 1 : 1;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _error = null;
      }
    });
    try {
      final result = await _catalog.products(_query, page: page, perPage: HomeScreen.pageSize);
      if (!mounted || id != _request) return;
      setState(() {
        _items = more ? [..._items, ...result.items] : result.items;
        _page = result.page;
        _total = result.total;
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _request) return;
      if (!more) setState(() => _error = e.message);
    } finally {
      if (mounted && id == _request) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_hasMore && !_loading && !_loadingMore && _scroll.position.extentAfter < 500) _loadProducts(more: true);
  }

  void _setQuery(ProductQuery query) {
    _query = query;
    _loadProducts();
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
    final result = await FilterSheet.show(context, query: _query, categories: _categories);
    if (result != null) _setQuery(result);
  }

  Future<void> _refresh() async {
    await Future.wait([_loadProducts(), _loadExtras(), context.read<ShopProvider>().refresh()]);
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
            controller: _scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    children: [
                      _BrandBar(onOpenCart: widget.onOpenCart),
                      const SizedBox(height: 18),
                      _SearchRow(
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
                  child: _ListHeader(
                    title: _title,
                    subtitle: _query.isFiltered && !_loading && _error == null ? '$_total ${_total == 1 ? 'item' : 'items'}' : null,
                    sort: _query.sort,
                    onSort: (s) => _setQuery(_query.copyWith(sort: s)),
                  ),
                ),
              ),
              ..._content(context),
              SliverToBoxAdapter(child: _Footer(loadingMore: _loadingMore, end: !_hasMore && _items.length > HomeScreen.pageSize)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    if (_loading && _items.isEmpty) return [_grid(context, 4, (_) => const ProductCardSkeleton())];
    if (_error != null) {
      return [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                ErrorBanner(message: _error!),
                const SizedBox(height: 12),
                PillButton(key: const Key('home_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _loadProducts),
              ],
            ),
          ),
        ),
      ];
    }
    if (_items.isEmpty) return [SliverToBoxAdapter(child: _EmptyState(onClear: _clearAll))];

    final shop = context.watch<ShopProvider>();
    return [
      _grid(context, _items.length, (i) {
        final p = _items[i];
        return ProductCard(
          product: p,
          wishlisted: shop.isWishlisted(p.id),
          onTap: () => ShopActions.openProduct(context, p),
          onToggleWishlist: () => ShopActions.toggleWishlist(context, p),
          onAddToCart: () => ShopActions.addToCart(context, p),
        );
      }),
    ];
  }

  Widget _grid(BuildContext context, int count, Widget Function(int) builder) {
    final scaler = MediaQuery.textScalerOf(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          const gap = 12.0;
          final columns = (constraints.crossAxisExtent / 200).floor().clamp(2, 4);
          final width = (constraints.crossAxisExtent - gap * (columns - 1)) / columns;
          return SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: ProductCard.heightFor(width, scaler),
            ),
            delegate: SliverChildBuilderDelegate((_, i) => builder(i), childCount: count),
          );
        },
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
    final cartCount = context.watch<ShopProvider>().cartCount;
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
        Badge(
          key: const Key('cart_badge'),
          isLabelVisible: cartCount > 0,
          label: Text('$cartCount'),
          backgroundColor: AppTheme.coral,
          offset: const Offset(-2, 2),
          child: RoundIconButton(icon: Icons.shopping_cart_outlined, tooltip: 'Cart', onPressed: onOpenCart),
        ),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  final TextEditingController controller;
  final int filterCount;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear, onFilter;

  const _SearchRow({
    required this.controller,
    required this.filterCount,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onFilter,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: TextField(
              key: const Key('home_search'),
              controller: controller,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: 'Search figures, cards, series...',
                filled: true,
                fillColor: dark ? scheme.surfaceContainerHigh : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                ),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded), onPressed: onClear),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Badge(
          isLabelVisible: filterCount > 0,
          label: Text('$filterCount'),
          backgroundColor: AppTheme.coral,
          child: IconButton.filled(
            key: const Key('home_filter'),
            tooltip: 'Filters',
            onPressed: onFilter,
            style: IconButton.styleFrom(backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white, fixedSize: const Size(52, 52)),
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ProductSort sort;
  final ValueChanged<ProductSort> onSort;

  const _ListHeader({required this.title, this.subtitle, required this.sort, required this.onSort});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        PopupMenuButton<ProductSort>(
          key: const Key('home_sort'),
          tooltip: 'Sort',
          initialValue: sort,
          onSelected: onSort,
          itemBuilder: (_) => [for (final s in ProductSort.values) PopupMenuItem(value: s, child: Text(s.label))],
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
            decoration: BoxDecoration(
              color: dark ? scheme.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: dark ? 0.3 : 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sort == ProductSort.newest ? 'Newest' : sort.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.swap_vert_rounded, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
      child: Column(
        children: [
          const IconCircle(icon: Icons.search_off_rounded),
          const SizedBox(height: 16),
          const Text('No products found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Try another word or clear the filters.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 18),
          PillButton(key: const Key('home_clear'), label: 'Clear filters', leadingIcon: Icons.filter_alt_off_rounded, onPressed: onClear),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool loadingMore, end;

  const _Footer({required this.loadingMore, required this.end});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Center(
        child: loadingMore
            ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))
            : (end
                ? Text("You've seen everything", style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))
                : const SizedBox.shrink()),
      ),
    );
  }
}
