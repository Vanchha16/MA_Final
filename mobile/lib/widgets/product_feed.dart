import 'dart:async';

import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:provider/provider.dart';

import '../api/api_client.dart';
import '../models/catalog.dart';
import '../providers/shop_provider.dart';
import '../services/catalog_service.dart';
import '../screens/shop/shop_actions.dart';
import 'error_banner.dart';
import 'icon_circle.dart';
import 'pill_button.dart';
import 'product_card.dart';
import 'product_tile.dart';

/// Loads products page by page (infinite_scroll_pagination). Give it a
/// [load] function for one page; call [refresh] when the query changes.
class ProductFeed {
  final Future<ProductPage> Function(int page) load;

  ProductFeed(this.load);

  int _totalPages = 1;

  /// Number of matching products, known after the first page.
  final total = ValueNotifier<int?>(null);

  late final controller = PagingController<int, Product>(
    getNextPageKey: (state) {
      final last = state.keys?.last;
      if (last == null) return 1;
      return last < _totalPages ? last + 1 : null;
    },
    fetchPage: (page) async {
      final result = await load(page);
      _totalPages = result.totalPages;
      total.value = result.total;
      return result.items;
    },
  );

  void refresh() {
    total.value = null;
    controller.refresh();
  }

  /// For pull-to-refresh: starts again and completes when the first page is in.
  Future<void> reload() {
    final done = Completer<void>();
    void check() {
      final s = controller.value;
      if (!s.isLoading && (s.pages != null || s.error != null) && !done.isCompleted) done.complete();
    }

    controller.addListener(check);
    refresh();
    controller.fetchNextPage();
    return done.future.whenComplete(() => controller.removeListener(check));
  }

  void dispose() {
    controller.dispose();
    total.dispose();
  }
}

/// The product grid as a sliver: product cards, shimmer while the first page
/// loads, more pages while scrolling, and empty / error states.
class ProductFeedGrid extends StatelessWidget {
  final ProductFeed feed;

  /// Passed on to Product Details (tests inject a fake).
  final CatalogService? catalogService;

  /// Rows (photo left, details right) instead of the 2-column grid.
  final bool listView;

  /// Shown on the empty state ("Clear filters"); hidden when null.
  final VoidCallback? onClear;
  final String emptyTitle;
  final String emptyMessage;

  const ProductFeedGrid({
    super.key,
    required this.feed,
    this.catalogService,
    this.listView = false,
    this.onClear,
    this.emptyTitle = 'No products found',
    this.emptyMessage = 'Try another word or clear the filters.',
  });

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    final scaler = MediaQuery.textScalerOf(context);

    return PagingListener(
      controller: feed.controller,
      builder: (context, state, fetchNextPage) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        sliver: SliverLayoutBuilder(
          builder: (context, constraints) {
            final columns = (constraints.crossAxisExtent / 200).floor().clamp(2, 4);
            final width = (constraints.crossAxisExtent - _gap * (columns - 1)) / columns;
            final height = ProductCard.heightFor(width, scaler);

            final delegate = PagedChildBuilderDelegate<Product>(
              itemBuilder: (context, p, _) => listView
                  ? ProductTile(
                      product: p,
                      wishlisted: shop.isWishlisted(p.id),
                      onTap: () => ShopActions.openProduct(context, p, catalog: catalogService),
                      onToggleWishlist: () => ShopActions.toggleWishlist(context, p),
                      onAddToCart: () => ShopActions.addToCart(context, p),
                    )
                  : ProductCard(
                      product: p,
                      wishlisted: shop.isWishlisted(p.id),
                      onTap: () => ShopActions.openProduct(context, p, catalog: catalogService),
                      onToggleWishlist: () => ShopActions.toggleWishlist(context, p),
                      onAddToCart: () => ShopActions.addToCart(context, p),
                    ),
              firstPageProgressIndicatorBuilder: (_) => _SkeletonRows(columns: columns, height: height),
              firstPageErrorIndicatorBuilder: (_) => _ErrorState(error: state.error, onRetry: feed.refresh),
              newPageErrorIndicatorBuilder: (_) => Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Center(
                  child: TextButton.icon(
                    onPressed: fetchNextPage,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Could not load more. Try again'),
                  ),
                ),
              ),
              noItemsFoundIndicatorBuilder: (_) => _EmptyState(title: emptyTitle, message: emptyMessage, onClear: onClear),
              newPageProgressIndicatorBuilder: (_) => const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2.5))),
              ),
              noMoreItemsIndicatorBuilder: (context) => (state.items?.length ?? 0) <= 10
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Center(
                        child: Text(
                          "You've seen everything",
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
            );

            if (listView) {
              return PagedSliverList<int, Product>.separated(
                state: state,
                fetchNextPage: fetchNextPage,
                separatorBuilder: (_, _) => const SizedBox(height: _gap),
                builderDelegate: delegate,
              );
            }
            return PagedSliverGrid<int, Product>(
              state: state,
              fetchNextPage: fetchNextPage,
              showNewPageProgressIndicatorAsGridChild: false,
              showNoMoreItemsIndicatorAsGridChild: false,
              showNewPageErrorIndicatorAsGridChild: false,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: _gap,
                crossAxisSpacing: _gap,
                mainAxisExtent: height,
              ),
              builderDelegate: delegate,
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonRows extends StatelessWidget {
  final int columns;
  final double height;

  const _SkeletonRows({required this.columns, required this.height});

  @override
  Widget build(BuildContext context) {
    Widget line() => SizedBox(
      height: height,
      child: Row(
        children: [
          for (var i = 0; i < columns; i++) ...[
            if (i > 0) const SizedBox(width: ProductFeedGrid._gap),
            const Expanded(child: ProductCardSkeleton()),
          ],
        ],
      ),
    );
    return Column(
      children: [
        line(),
        const SizedBox(height: ProductFeedGrid._gap),
        line(),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Object? error;
  final VoidCallback onRetry;

  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException ? (error as ApiException).message : 'Something went wrong. Please try again.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ErrorBanner(message: message),
        const SizedBox(height: 12),
        PillButton(key: const Key('feed_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: onRetry),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title, message;
  final VoidCallback? onClear;

  const _EmptyState({required this.title, required this.message, this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IconCircle(icon: Icons.search_off_rounded),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (onClear != null) ...[
            const SizedBox(height: 18),
            PillButton(key: const Key('feed_clear'), label: 'Clear filters', leadingIcon: Icons.filter_alt_off_rounded, onPressed: onClear),
          ],
        ],
      ),
    );
  }
}
