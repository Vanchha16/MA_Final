/// Product group, e.g. "Scale Figures" or "TCG Boosters".
class Category {
  final int id;
  final String name;
  final String slug;
  final int productCount;

  /// Main photo of one of its products, for the Categories tiles.
  final String? coverImage;

  const Category({required this.id, required this.name, required this.slug, this.productCount = 0, this.coverImage});

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'],
        name: json['name'],
        slug: json['slug'],
        productCount: json['product_count'] ?? 0,
        coverImage: json['cover_image'],
      );

  /// Figures, plush, model kits or trading cards - picks the placeholder look.
  ProductKind get kind {
    if (slug.startsWith('tcg')) return ProductKind.tcg;
    if (slug.contains('plush')) return ProductKind.plush;
    if (slug.contains('model')) return ProductKind.kit;
    return ProductKind.figure;
  }
}

enum ProductKind { figure, plush, kit, tcg }

/// Anime franchise, e.g. One Piece or Pokemon.
class Series {
  final int id;
  final String name;
  final String slug;
  final int productCount;
  final String? coverImage;

  const Series({required this.id, required this.name, required this.slug, this.productCount = 0, this.coverImage});

  factory Series.fromJson(Map<String, dynamic> json) => Series(
        id: json['id'],
        name: json['name'],
        slug: json['slug'],
        productCount: json['product_count'] ?? 0,
        coverImage: json['cover_image'],
      );

  /// "OP" for One Piece, "SX" for Spy x Family - shown when there is no photo.
  String get initials {
    final words = name.replaceAll(RegExp(r'[^A-Za-z ]'), ' ').split(' ').where((w) => w.isNotEmpty).toList();
    if (words.length == 1) return words.first.substring(0, words.first.length.clamp(0, 2)).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

class Product {
  final int id;
  final String name;
  final String? brand;
  final String? description;
  final double price;
  final double? discountPrice;
  final int stock;
  final bool isFeatured;
  final String? imageUrl;

  /// All photos, main photo first (the gallery on Product Details).
  final List<String> images;
  final Category category;
  final Series? series;
  final double rating;
  final int reviewCount;

  const Product({
    required this.id,
    required this.name,
    this.brand,
    this.description,
    required this.price,
    this.discountPrice,
    required this.stock,
    this.isFeatured = false,
    this.imageUrl,
    this.images = const [],
    required this.category,
    this.series,
    this.rating = 0,
    this.reviewCount = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'],
        name: json['name'],
        brand: json['brand'],
        description: json['description'],
        price: (json['price'] as num).toDouble(),
        discountPrice: (json['discount_price'] as num?)?.toDouble(),
        stock: json['stock'] ?? 0,
        isFeatured: json['is_featured'] ?? false,
        imageUrl: json['image_url'],
        images: [for (final i in json['images'] as List? ?? []) i as String],
        category: Category.fromJson(json['category']),
        series: json['series'] == null ? null : Series.fromJson(json['series']),
        rating: (json['rating'] as num? ?? 0).toDouble(),
        reviewCount: json['review_count'] ?? 0,
      );

  double get finalPrice => discountPrice ?? price;
  bool get onSale => discountPrice != null && discountPrice! < price;
  bool get soldOut => stock <= 0;

  /// Whole-number discount, e.g. 11 for $189 -> $169.
  int get discountPercent => onSale ? ((1 - discountPrice! / price) * 100).round() : 0;
}

/// The quick tags a customer can add to a review (API key -> label).
const reviewTags = {
  'quality': 'Great quality',
  'as_pictured': 'As pictured',
  'packaging': 'Well packed',
  'delivery': 'Fast delivery',
  'value': 'Good value',
};

/// Words for 1-5 stars.
const ratingWords = ['', 'Terrible', 'Not great', 'Okay', 'Very good', 'Excellent'];

DateTime _utc(String raw) {
  // The API sends UTC without a zone marker
  final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
  return DateTime.parse(hasZone ? raw : '${raw}Z');
}

class Review {
  final int id;
  final int? productId;
  final String user;
  final int rating;
  final String? comment;
  final List<String> tags;
  final DateTime createdAt;
  final bool edited;

  /// The logged-in customer wrote it.
  final bool isMine;

  const Review({
    required this.id,
    this.productId,
    required this.user,
    required this.rating,
    this.comment,
    this.tags = const [],
    required this.createdAt,
    this.edited = false,
    this.isMine = false,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'],
        productId: json['product_id'],
        user: json['user'],
        rating: json['rating'],
        comment: json['comment'],
        tags: [for (final t in json['tags'] as List? ?? const []) if (reviewTags.containsKey(t)) t as String],
        createdAt: _utc(json['created_at'] as String),
        edited: json['edited'] ?? false,
        isMine: json['is_mine'] ?? false,
      );

  /// "DC" for Demo Customer.
  String get initials => user.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();

  bool get hasComment => (comment ?? '').trim().isNotEmpty;
}

/// Average, count and how many reviews gave each star / chose each tag.
class ReviewSummary {
  final double rating;
  final int count, withComment;
  final Map<int, int> stars;
  final Map<String, int> tags;

  const ReviewSummary({this.rating = 0, this.count = 0, this.withComment = 0, this.stars = const {}, this.tags = const {}});

  factory ReviewSummary.fromJson(Map<String, dynamic> json) => ReviewSummary(
        rating: (json['rating'] as num? ?? 0).toDouble(),
        count: json['count'] ?? 0,
        withComment: json['with_comment'] ?? 0,
        stars: {for (final e in (json['stars'] as Map? ?? const {}).entries) int.parse('${e.key}'): e.value as int},
        tags: {for (final e in (json['tags'] as Map? ?? const {}).entries) '${e.key}': e.value as int},
      );

  int starCount(int n) => stars[n] ?? 0;

  /// Share of reviews with [n] stars, 0..1.
  double share(int n) => count == 0 ? 0 : starCount(n) / count;
}

/// GET /api/products/{id}/reviews: one page plus the summary.
class ReviewPage {
  final ReviewSummary summary;
  final List<Review> items;
  final int page, totalPages, total;

  const ReviewPage({required this.summary, this.items = const [], this.page = 1, this.totalPages = 1, this.total = 0});

  factory ReviewPage.fromJson(Map<String, dynamic> json) => ReviewPage(
        summary: ReviewSummary.fromJson(json['summary']),
        items: [for (final r in json['items'] as List) Review.fromJson(r)],
        page: json['page'],
        totalPages: json['total_pages'],
        total: json['total'],
      );

  bool get hasMore => page < totalPages;
}

/// A delivered product the customer hasn't rated yet (GET /api/reviews/to-review).
class ToReviewItem {
  final Product product;
  final int orderId;
  final String orderNumber;

  const ToReviewItem({required this.product, required this.orderId, required this.orderNumber});

  factory ToReviewItem.fromJson(Map<String, dynamic> json) =>
      ToReviewItem(product: Product.fromJson(json['product']), orderId: json['order_id'], orderNumber: json['order_number']);
}

/// GET /api/products/{id}: the product plus its reviews and related products.
class ProductDetail {
  final Product product;
  final List<Review> reviews;
  final ReviewSummary summary;
  final List<Product> related;

  /// The logged-in customer's own review, and whether they may write one (it was delivered to them).
  final Review? myReview;
  final bool canReview;

  const ProductDetail({
    required this.product,
    this.reviews = const [],
    this.summary = const ReviewSummary(),
    this.related = const [],
    this.myReview,
    this.canReview = false,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        product: Product.fromJson(json),
        reviews: [for (final r in json['reviews'] as List? ?? []) Review.fromJson(r)],
        summary: json['review_summary'] == null ? const ReviewSummary() : ReviewSummary.fromJson(json['review_summary']),
        related: [for (final p in json['related'] as List? ?? []) Product.fromJson(p)],
        myReview: json['my_review'] == null ? null : Review.fromJson(json['my_review']),
        canReview: json['can_review'] ?? false,
      );
}

/// While typing in Search: GET /api/search/suggestions.
class SearchSuggestions {
  final List<Product> products;
  final List<String> keywords;

  /// All matching products (the "See all N results" button).
  final int total;

  const SearchSuggestions({this.products = const [], this.keywords = const [], this.total = 0});

  factory SearchSuggestions.fromJson(Map<String, dynamic> json) => SearchSuggestions(
        products: [for (final p in json['products'] as List? ?? []) Product.fromJson(p)],
        keywords: [for (final k in json['keywords'] as List? ?? []) k as String],
        total: json['total'] ?? 0,
      );
}

/// One page of GET /api/products.
class ProductPage {
  final List<Product> items;
  final int page;
  final int totalPages;
  final int total;

  const ProductPage({required this.items, required this.page, required this.totalPages, required this.total});

  factory ProductPage.fromJson(Map<String, dynamic> json) => ProductPage(
        items: [for (final p in json['items'] as List) Product.fromJson(p)],
        page: json['page'],
        totalPages: json['total_pages'],
        total: json['total'],
      );

  bool get hasMore => page < totalPages;
}

enum ProductSort {
  newest('newest', 'Newest', 'Newest'),
  priceAsc('price_asc', 'Price: low to high', 'Lowest price'),
  priceDesc('price_desc', 'Price: high to low', 'Highest price'),
  name('name', 'Name A-Z', 'A-Z');

  final String apiValue;

  /// In the sort menu.
  final String label;

  /// On the small sort button.
  final String short;
  const ProductSort(this.apiValue, this.label, this.short);
}

/// Everything that narrows the product list: search text, series tab and
/// the filter sheet (category, price range, in stock), plus the sort order.
class ProductQuery {
  final String q;
  final int? seriesId;
  final int? categoryId;

  /// Any of these brands (empty = all brands).
  final List<String> brands;
  final double? minPrice;
  final double? maxPrice;
  final bool inStockOnly;
  final ProductSort sort;

  const ProductQuery({
    this.q = '',
    this.seriesId,
    this.categoryId,
    this.brands = const [],
    this.minPrice,
    this.maxPrice,
    this.inStockOnly = false,
    this.sort = ProductSort.newest,
  });

  /// Filters chosen in the filter sheet (not search, series tab or sort).
  int get activeFilterCount =>
      (categoryId != null ? 1 : 0) +
      (brands.isNotEmpty ? 1 : 0) +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (inStockOnly ? 1 : 0);

  bool get isFiltered => q.isNotEmpty || seriesId != null || activeFilterCount > 0;

  /// Nullable fields take a function so they can be set back to null:
  /// `copyWith(seriesId: () => null)`.
  ProductQuery copyWith({
    String? q,
    int? Function()? seriesId,
    int? Function()? categoryId,
    List<String>? brands,
    double? Function()? minPrice,
    double? Function()? maxPrice,
    bool? inStockOnly,
    ProductSort? sort,
  }) =>
      ProductQuery(
        q: q ?? this.q,
        seriesId: seriesId != null ? seriesId() : this.seriesId,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        brands: brands ?? this.brands,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        inStockOnly: inStockOnly ?? this.inStockOnly,
        sort: sort ?? this.sort,
      );

  /// Clears search, series tab and filters; keeps the sort order.
  ProductQuery cleared() => ProductQuery(sort: sort);

  Map<String, dynamic> toParams({int page = 1, int perPage = 10}) => {
        if (q.isNotEmpty) 'q': q,
        if (seriesId != null) 'series_id': seriesId,
        if (categoryId != null) 'category_id': categoryId,
        if (brands.isNotEmpty) 'brand': brands,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
        if (inStockOnly) 'in_stock': 1,
        'sort': sort.apiValue,
        'page': page,
        'per_page': perPage,
      };
}
