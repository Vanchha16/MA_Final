import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../services/catalog_service.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/shop_search_bar.dart';
import 'product_list_screen.dart';

/// Categories tab (Figma: Categories A - Photo Grid): a 2-column grid of
/// categories with a product photo and item count, then "Shop by anime"
/// series circles. Every tile opens the Product List.
class CategoriesScreen extends StatefulWidget {
  /// Injected in tests; the real API otherwise.
  final CatalogService? catalogService;
  final VoidCallback? onOpenCart;

  const CategoriesScreen({super.key, this.catalogService, this.onOpenCart});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  final _search = TextEditingController();

  List<Category>? _categories;
  List<Series> _series = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final categories = _catalog.categories();
      final series = _catalog.series();
      final results = await Future.wait([categories, series]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<Category>;
        _series = results[1] as List<Series>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _open(String title, ProductQuery query) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductListScreen(title: title, query: query, catalogService: widget.catalogService),
    ),
  );

  void _searchAll(String text) {
    final q = text.trim();
    if (q.isEmpty) return;
    _open('Results for "$q"', ProductQuery(q: q));
    _search.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final categories = _categories;
    final total = categories?.fold<int>(0, (sum, c) => sum + c.productCount);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Categories', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                                Text(
                                  categories == null ? 'Find your next collectible' : '${categories.length} categories · $total products',
                                  style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          CartButton(onPressed: widget.onOpenCart),
                        ],
                      ),
                      const SizedBox(height: 18),
                      ShopSearchBar(
                        controller: _search,
                        fieldKey: const Key('categories_search'),
                        hint: 'Search in all categories...',
                        onChanged: (_) => setState(() {}),
                        onSubmitted: _searchAll,
                        onClear: () => setState(_search.clear),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (_error != null)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        ErrorBanner(message: _error!),
                        const SizedBox(height: 12),
                        PillButton(
                          key: const Key('categories_retry'),
                          label: 'Try again',
                          leadingIcon: Icons.refresh_rounded,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      const gap = 12.0;
                      final width = (constraints.crossAxisExtent - gap) / 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: gap,
                          crossAxisSpacing: gap,
                          // Square photo (never cropped) + name and count
                          mainAxisExtent: width + MediaQuery.textScalerOf(context).scale(_CategoryTile.infoHeight),
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => categories == null
                              ? const _TileSkeleton()
                              : _CategoryTile(
                                  category: categories[i],
                                  onTap: () => _open(categories[i].name, ProductQuery(categoryId: categories[i].id)),
                                ),
                          childCount: categories?.length ?? 6,
                        ),
                      );
                    },
                  ),
                ),
                if (_series.isNotEmpty) ...[
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(24, 26, 24, 14),
                    sliver: SliverToBoxAdapter(
                      child: Text('Shop by anime', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(16) + 82,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _series.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (_, i) => _SeriesCircle(
                          series: _series[i],
                          onTap: () => _open(_series[i].name, ProductQuery(seriesId: _series[i].id)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
              const SliverToBoxAdapter(child: SizedBox(height: 28)),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(22),
    boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
  );
}

class _CategoryTile extends StatelessWidget {
  /// Height of the name and count under the square photo, at normal text size.
  static const double infoHeight = 64;

  final Category category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final count = category.productCount;
    return DecoratedBox(
      decoration: _cardDecoration(context),
      child: Material(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('category_${category.slug}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ProductImage(url: category.coverImage, kind: category.kind, iconSize: 44, borderRadius: BorderRadius.zero),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text('$count ${count == 1 ? 'item' : 'items'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    ],
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

class _SeriesCircle extends StatelessWidget {
  final Series series;
  final VoidCallback onTap;

  const _SeriesCircle({required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: '${series.name}, ${series.productCount} items',
      excludeSemantics: true,
      child: InkWell(
        key: Key('series_tile_${series.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dark ? scheme.surfaceContainerHigh : Colors.white,
                  border: Border.all(color: scheme.primary.withValues(alpha: 0.25), width: 2),
                  boxShadow: [
                    if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4)),
                  ],
                ),
                child: ClipOval(
                  child: series.coverImage == null
                      ? Center(
                          child: Text(
                            series.initials,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: dark ? scheme.primary : AppTheme.primaryDark,
                            ),
                          ),
                        )
                      : ProductImage(url: series.coverImage, kind: ProductKind.figure, iconSize: 24, borderRadius: BorderRadius.zero),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                series.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Shimmer.fromColors(
      enabled: !reduceMotion,
      baseColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE8F1FA),
      highlightColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF7FBFF),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}
