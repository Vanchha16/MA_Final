import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:provider/provider.dart';
import 'package:readmore/readmore.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/catalog.dart';
import '../../providers/shop_provider.dart';
import '../../services/catalog_service.dart';
import '../../widgets/cart_button.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_image.dart';
import '../shell/main_shell.dart';
import '../shop/shop_actions.dart';
import 'product_list_screen.dart';

/// Product Details (Figma: Details A - Classic Gallery): swipeable photos
/// with full-screen zoom, chips, rating, price and stock, description,
/// reviews and more from the same series, and a quantity + Add to cart bar.
///
/// Opens instantly with the [product] from the card, then loads reviews and
/// related products.
class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final CatalogService? catalogService;

  const ProductDetailsScreen({super.key, required this.product, this.catalogService});

  /// Most of one item a customer can put in the cart at once (matches the API).
  static const maxQuantity = 20;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  late Product _product = widget.product;
  ProductDetail? _detail;
  String? _error;
  int _quantity = 1;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final detail = await _catalog.product(widget.product.id);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _product = detail.product;
        _quantity = _quantity.clamp(1, _maxQuantity);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  int get _maxQuantity => _product.stock.clamp(1, ProductDetailsScreen.maxQuantity);

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      await ShopActions.addToCart(context, _product, quantity: _quantity);
    } catch (_) {
      // ShopActions already told the user why
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  void _openList(String title, ProductQuery query) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => ProductListScreen(title: title, query: query, catalogService: widget.catalogService),
    ),
  );

  void _openCart() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.requestedTab.value = MainShell.cartTab;
  }

  @override
  Widget build(BuildContext context) {
    final p = _product;
    final scheme = Theme.of(context).colorScheme;
    final wishlisted = context.watch<ShopProvider>().isWishlisted(p.id);
    final reviews = _detail?.reviews ?? const <Review>[];
    final related = _detail?.related ?? const <Product>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Gallery(
              product: p,
              wishlisted: wishlisted,
              onBack: () => Navigator.of(context).maybePop(),
              onCart: _openCart,
              onWishlist: () => ShopActions.toggleWishlist(context, p),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            sliver: SliverList.list(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (p.series != null)
                      _InfoChip(
                        key: const Key('chip_series'),
                        label: p.series!.name,
                        highlighted: true,
                        onTap: () => _openList(p.series!.name, ProductQuery(seriesId: p.series!.id)),
                      ),
                    if (p.brand != null) _InfoChip(label: p.brand!),
                    _InfoChip(
                      key: const Key('chip_category'),
                      label: p.category.name,
                      onTap: () => _openList(p.category.name, ProductQuery(categoryId: p.category.id)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(p.name, style: const TextStyle(fontSize: 22, height: 1.27, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _RatingRow(rating: p.rating, count: p.reviewCount),
                    ),
                    const SizedBox(width: 8),
                    _StockChip(product: p),
                  ],
                ),
                const SizedBox(height: 12),
                _PriceRow(product: p),
                if ((p.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _SectionTitle('Description'),
                  const SizedBox(height: 6),
                  ReadMoreText(
                    p.description!,
                    trimMode: TrimMode.Line,
                    trimLines: 3,
                    trimCollapsedText: ' Read more',
                    trimExpandedText: ' Show less',
                    style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
                    moreStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.primary),
                    lessStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: scheme.primary),
                  ),
                ],
                const SizedBox(height: 22),
                if (_error != null) ...[
                  ErrorBanner(message: _error!),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const Key('details_retry'),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Try again'),
                    ),
                  ),
                ] else ...[
                  _SectionTitle(
                    'Reviews (${_detail == null ? p.reviewCount : reviews.length})',
                    action: reviews.length > 1 ? 'See all' : null,
                    onAction: () => _ReviewsSheet.show(context, reviews),
                  ),
                  const SizedBox(height: 10),
                  if (_detail == null)
                    const Center(
                      child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2.5)),
                    )
                  else if (reviews.isEmpty)
                    Text('No reviews yet. Be the first after your order arrives!', style: TextStyle(color: scheme.onSurfaceVariant))
                  else
                    _ReviewCard(review: reviews.first),
                ],
              ],
            ),
          ),
          if (related.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 12),
              sliver: SliverToBoxAdapter(child: _SectionTitle('More from ${p.series?.name ?? p.category.name}')),
            ),
            SliverToBoxAdapter(
              child: _RelatedRow(products: related, catalogService: widget.catalogService),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        product: p,
        quantity: _quantity,
        maxQuantity: _maxQuantity,
        adding: _adding,
        onQuantity: (q) => setState(() => _quantity = q),
        onAdd: _addToCart,
      ),
    );
  }
}

class _Gallery extends StatefulWidget {
  final Product product;
  final bool wishlisted;
  final VoidCallback onBack, onCart, onWishlist;

  const _Gallery({required this.product, required this.wishlisted, required this.onBack, required this.onCart, required this.onWishlist});

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pages = PageController();
  int _index = 0;

  List<String?> get _images {
    final p = widget.product;
    if (p.images.isNotEmpty) return p.images;
    return [p.imageUrl];
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _openViewer() {
    final urls = _images.whereType<String>().toList();
    if (urls.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, _, _) => _PhotoViewer(urls: urls, initial: _index.clamp(0, urls.length - 1), productId: widget.product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final images = _images;
    final scheme = Theme.of(context).colorScheme;
    final top = MediaQuery.paddingOf(context).top;
    final height = (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, 460.0);

    return Column(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
          child: SizedBox(
            height: height + top,
            child: Stack(
              children: [
                PageView.builder(
                  key: const Key('details_gallery'),
                  controller: _pages,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) {
                    final image = ProductImage(url: images[i], kind: p.category.kind, iconSize: 120, borderRadius: BorderRadius.zero);
                    return GestureDetector(
                      onTap: _openViewer,
                      child: Padding(
                        padding: EdgeInsets.only(top: top),
                        child: i == 0 ? Hero(tag: ProductCard.heroTag(p.id), child: image) : image,
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  top: top + 8,
                  child: Row(
                    children: [
                      CircleBackButton(onPressed: widget.onBack),
                      const Spacer(),
                      CartButton(onPressed: widget.onCart),
                      const SizedBox(width: 10),
                      _CircleAction(
                        key: const Key('details_wishlist'),
                        tooltip: widget.wishlisted ? 'Remove from wishlist' : 'Add to wishlist',
                        icon: widget.wishlisted ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: AppTheme.coral,
                        onPressed: widget.onWishlist,
                      ),
                    ],
                  ),
                ),
                if (images.length > 1)
                  Positioned(
                    right: 16,
                    bottom: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0x8C0F172A), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        '${_index + 1} / ${images.length}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: 12),
          SmoothPageIndicator(
            controller: _pages,
            count: images.length,
            onDotClicked: (i) => _pages.animateToPage(i, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic),
            effect: ExpandingDotsEffect(
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 3.4,
              spacing: 6,
              activeDotColor: scheme.primary,
              dotColor: scheme.primary.withValues(alpha: 0.25),
            ),
          ),
        ],
      ],
    );
  }
}

/// Full-screen, pinch-to-zoom photos (photo_view).
class _PhotoViewer extends StatefulWidget {
  final List<String> urls;
  final int initial;
  final int productId;

  const _PhotoViewer({required this.urls, required this.initial, required this.productId});

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            key: const Key('photo_viewer'),
            pageController: _controller,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (_, i) => PhotoViewGalleryPageOptions(
              imageProvider: CachedNetworkImageProvider(widget.urls[i]),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(tag: 'viewer-${widget.productId}-$i'),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filled(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(backgroundColor: Colors.white24, foregroundColor: Colors.white),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const Spacer(),
                  if (widget.urls.length > 1)
                    Text(
                      '${_index + 1} / ${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CircleAction({super.key, required this.tooltip, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.10), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: IconButton.filled(
        tooltip: tooltip,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          backgroundColor: dark ? scheme.surfaceContainerHigh : Colors.white,
          foregroundColor: color,
          fixedSize: const Size(44, 44),
        ),
        icon: Icon(icon, size: 22),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final bool highlighted;
  final VoidCallback? onTap;

  const _InfoChip({super.key, required this.label, this.highlighted = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = highlighted
        ? (dark ? scheme.primaryContainer : AppTheme.skyTint)
        : scheme.surfaceContainerHighest.withValues(alpha: dark ? 1 : 0.6);
    final fg = highlighted ? (dark ? scheme.onPrimaryContainer : AppTheme.primaryDark) : scheme.onSurfaceVariant;
    return Material(
      color: bg,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
              ),
              if (onTap != null) ...[const SizedBox(width: 2), Icon(Icons.chevron_right_rounded, size: 16, color: fg)],
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  final double rating;
  final int count;

  const _RatingRow({required this.rating, required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        RatingBarIndicator(
          rating: rating,
          itemCount: 5,
          itemSize: 18,
          unratedColor: scheme.outlineVariant,
          itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            count == 0 ? 'No reviews yet' : '${rating.toStringAsFixed(1)}  ($count ${count == 1 ? 'review' : 'reviews'})',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Product product;

  const _PriceRow({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          formatPrice(p.finalPrice),
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: dark ? scheme.primary : AppTheme.primaryDark),
        ),
        if (p.onSale) ...[
          Text(
            formatPrice(p.price),
            style: TextStyle(
              fontSize: 15,
              color: scheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
              decorationColor: scheme.onSurfaceVariant,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppTheme.coral, borderRadius: BorderRadius.circular(10)),
            child: Text(
              '-${p.discountPercent}%',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }
}

class _StockChip extends StatelessWidget {
  final Product product;

  const _StockChip({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final (stockText, stockColor, stockIcon) = p.soldOut
        ? ('Sold out', AppTheme.danger, Icons.remove_shopping_cart_outlined)
        : p.stock <= 5
        ? ('Only ${p.stock} left', const Color(0xFFB45309), Icons.local_fire_department_outlined)
        : ('In stock', AppTheme.success, Icons.check_circle_outline_rounded);
    return Container(
      key: const Key('details_stock'),
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(color: stockColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stockIcon, size: 15, color: stockColor),
          const SizedBox(width: 4),
          Text(
            stockText,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: stockColor),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        ),
        if (action != null)
          TextButton(
            key: const Key('reviews_see_all'),
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
            child: Row(mainAxisSize: MainAxisSize.min, children: [Text(action!), const Icon(Icons.chevron_right_rounded, size: 18)]),
          ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Review review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppTheme.primaryDark,
                child: Text(
                  review.initials,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.user, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text(timeago.format(review.createdAt), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              RatingBarIndicator(
                rating: review.rating.toDouble(),
                itemCount: 5,
                itemSize: 14,
                unratedColor: scheme.outlineVariant,
                itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
              ),
            ],
          ),
          if ((review.comment ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!, style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}

/// All reviews in a bottom sheet (a full Reviews screen comes later).
class _ReviewsSheet {
  static Future<void> show(BuildContext context, List<Review> reviews) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (_, controller) => ListView.separated(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        itemCount: reviews.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => i == 0
            ? Text('Reviews (${reviews.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
            : _ReviewCard(review: reviews[i - 1]),
      ),
    ),
  );
}

class _RelatedRow extends StatelessWidget {
  final List<Product> products;
  final CatalogService? catalogService;

  const _RelatedRow({required this.products, this.catalogService});

  static const _width = 164.0;

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    return SizedBox(
      height: ProductCard.heightFor(_width, MediaQuery.textScalerOf(context)),
      child: ListView.separated(
        key: const Key('details_related'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final p = products[i];
          return SizedBox(
            width: _width,
            child: ProductCard(
              product: p,
              wishlisted: shop.isWishlisted(p.id),
              onTap: () => ShopActions.openProduct(context, p, catalog: catalogService),
              onToggleWishlist: () => ShopActions.toggleWishlist(context, p),
              onAddToCart: () => ShopActions.addToCart(context, p),
            ),
          );
        },
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final Product product;
  final int quantity, maxQuantity;
  final bool adding;
  final ValueChanged<int> onQuantity;
  final VoidCallback onAdd;

  const _BottomBar({
    required this.product,
    required this.quantity,
    required this.maxQuantity,
    required this.adding,
    required this.onQuantity,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final soldOut = product.soldOut;

    Widget stepButton(IconData icon, String tooltip, Key key, VoidCallback? onPressed) => IconButton.filled(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: dark ? scheme.surfaceContainerHighest : Colors.white,
        foregroundColor: dark ? scheme.primary : AppTheme.primaryDark,
        disabledBackgroundColor: Colors.transparent,
        fixedSize: const Size(44, 44),
      ),
      icon: Icon(icon, size: 20),
    );

    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        boxShadow: [
          if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            children: [
              if (!soldOut) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: dark ? scheme.surfaceContainerHigh : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      stepButton(
                        Icons.remove_rounded,
                        'Less',
                        const Key('qty_minus'),
                        quantity > 1 ? () => onQuantity(quantity - 1) : null,
                      ),
                      SizedBox(
                        width: 34,
                        child: Text(
                          '$quantity',
                          key: const Key('qty_value'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      stepButton(
                        Icons.add_rounded,
                        'More',
                        const Key('qty_plus'),
                        quantity < maxQuantity ? () => onQuantity(quantity + 1) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const Key('details_add'),
                    onPressed: soldOut || adding ? null : onAdd,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    icon: adding
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(soldOut ? Icons.remove_shopping_cart_outlined : Icons.shopping_cart_outlined, size: 20),
                    label: Text(soldOut ? 'Sold out' : 'Add to cart  ·  ${formatPrice(product.finalPrice * quantity)}'),
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
