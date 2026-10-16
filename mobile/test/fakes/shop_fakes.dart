import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/models/cart.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/services/catalog_service.dart';
import 'package:ecommerce_app/services/shop_service.dart';

const figures = Category(id: 1, name: 'Scale Figures', slug: 'scale-figures', productCount: 1);
const boosters = Category(id: 6, name: 'TCG Boosters', slug: 'tcg-boosters', productCount: 11);
const onePiece = Series(id: 1, name: 'One Piece', slug: 'one-piece', productCount: 11);
const pokemon = Series(id: 2, name: 'Pokemon', slug: 'pokemon', productCount: 1);

/// 12 products: 1 Luffy on sale, 1 sold-out Pokemon box, 10 One Piece packs.
final demoProducts = <Product>[
  const Product(id: 1, name: 'Monkey D. Luffy Gear 5 1/7 Scale Figure', brand: 'Good Smile Company', price: 189, discountPrice: 169,
      stock: 5, isFeatured: true, category: figures, series: onePiece),
  const Product(id: 2, name: 'Pokemon TCG Booster Box (36 packs)', brand: 'The Pokemon Company', price: 145, stock: 0,
      category: boosters, series: pokemon),
  for (var i = 3; i <= 12; i++)
    Product(id: i, name: 'One Piece Booster Pack #$i', brand: 'Bandai', price: 5, stock: 50, category: boosters, series: onePiece),
];

class FakeCatalogService extends CatalogService {
  final List<Product> products_;
  final List<ProductQuery> queries = [];
  final List<int> pages = [];
  bool fail = false;

  FakeCatalogService({List<Product>? products}) : products_ = products ?? demoProducts;

  ProductQuery? get lastQuery => queries.isEmpty ? null : queries.last;

  @override
  Future<List<Series>> series() async => [onePiece, pokemon];

  @override
  Future<List<Category>> categories() async => [figures, boosters];

  @override
  Future<List<String>> brands() async => ['Bandai', 'Good Smile Company', 'The Pokemon Company'];

  bool detailFails = false;
  final List<String> suggestionQueries = [];

  @override
  Future<SearchSuggestions> suggestions(String q) async {
    suggestionQueries.add(q);
    final matches = products_.where((p) => p.name.toLowerCase().contains(q.toLowerCase())).toList();
    final words = {
      for (final p in matches)
        for (final w in p.name.split(' '))
          if (w.toLowerCase().contains(q.toLowerCase())) w.toLowerCase(),
    };
    return SearchSuggestions(products: matches.take(5).toList(), keywords: words.take(5).toList(), total: matches.length);
  }

  @override
  Future<ProductDetail> product(int id) async {
    if (detailFails) throw ApiException('Cannot connect to server. Check your internet connection.');
    final p = products_.firstWhere((p) => p.id == id);
    return ProductDetail(
      product: p,
      reviews: [
        Review(id: 1, user: 'Demo Customer', rating: 5, comment: 'Great quality, fast delivery!', createdAt: DateTime.now().subtract(const Duration(days: 14))),
        Review(id: 2, user: 'Sok Dara', rating: 4, comment: 'Box arrived perfect.', createdAt: DateTime.now().subtract(const Duration(days: 3))),
      ],
      related: products_.where((o) => o.id != id && o.series?.id == p.series?.id).take(3).toList(),
    );
  }

  @override
  Future<ProductPage> products(ProductQuery query, {int page = 1, int perPage = 10, bool featuredOnly = false}) async {
    queries.add(query);
    pages.add(page);
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
    final matches = products_.where((p) {
      if (query.q.isNotEmpty && !p.name.toLowerCase().contains(query.q.toLowerCase())) return false;
      if (query.seriesId != null && p.series?.id != query.seriesId) return false;
      if (query.categoryId != null && p.category.id != query.categoryId) return false;
      if (query.brands.isNotEmpty && !query.brands.contains(p.brand)) return false;
      if (query.inStockOnly && p.soldOut) return false;
      if (featuredOnly && !p.isFeatured) return false;
      if (query.minPrice != null && p.finalPrice < query.minPrice!) return false;
      if (query.maxPrice != null && p.finalPrice > query.maxPrice!) return false;
      return true;
    }).toList();
    final start = (page - 1) * perPage;
    final items = matches.skip(start).take(perPage).toList();
    final totalPages = matches.isEmpty ? 0 : (matches.length / perPage).ceil();
    return ProductPage(items: items, page: page, totalPages: totalPages, total: matches.length);
  }
}

class FakeShopService extends ShopService {
  final Set<int> wishlist;
  int cart;

  FakeShopService({Set<int>? wishlist, this.cart = 0}) : wishlist = wishlist ?? {};

  @override
  Future<Set<int>> wishlistIds() async => {...wishlist};

  @override
  Future<void> addToWishlist(int productId) async => wishlist.add(productId);

  @override
  Future<void> removeFromWishlist(int productId) async => wishlist.remove(productId);

  @override
  Future<int> cartCount() async => cart;

  /// Unread messages for the bell badge.
  int unread = 0;

  @override
  Future<int> unreadNotifications() async => unread;

  /// Products the wishlist can show (defaults to [demoProducts]).
  List<Product> catalog = demoProducts;
  bool failWishlist = false;
  final List<List<int>> moves = [];

  @override
  Future<List<Product>> wishlistItems() async {
    if (failWishlist) throw ApiException('Cannot connect to server. Check your internet connection.');
    return [for (final id in wishlist) catalog.firstWhere((p) => p.id == id)];
  }

  @override
  Future<Set<int>> removeManyFromWishlist(List<int> productIds) async => {...wishlist..removeAll(productIds)};

  @override
  Future<Set<int>> addManyToWishlist(List<int> productIds) async {
    // Back on top, like the API
    final rest = wishlist.difference(productIds.toSet());
    wishlist
      ..clear()
      ..addAll([...productIds, ...rest]);
    return {...wishlist};
  }

  @override
  Future<MoveToCartResult> moveToCart(List<int> productIds) async {
    moves.add(productIds);
    final moved = [for (final id in productIds) if (!catalog.firstWhere((p) => p.id == id).soldOut) id];
    wishlist.removeAll(moved);
    cart += moved.length;
    return MoveToCartResult(
      moved: moved,
      skipped: [for (final id in productIds) if (!moved.contains(id)) id],
      wishlistIds: {...wishlist},
      cartCount: cart,
    );
  }

  /// What was added through this fake, for the cart totals (free delivery from $50, else $2).
  double subtotal = 0;

  @override
  Future<Cart> addToCart(int productId, {int quantity = 1}) async {
    cart += quantity;
    subtotal += demoProducts.firstWhere((p) => p.id == productId).finalPrice * quantity;
    final shipping = subtotal >= 50 ? 0.0 : 2.0;
    return Cart(count: cart, subtotal: subtotal, shippingFee: shipping, total: subtotal + shipping);
  }
}
