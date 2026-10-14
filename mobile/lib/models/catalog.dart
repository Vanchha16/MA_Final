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

class Review {
  final int id;
  final String user;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const Review({required this.id, required this.user, required this.rating, this.comment, required this.createdAt});

  factory Review.fromJson(Map<String, dynamic> json) {
    final raw = json['created_at'] as String;
    // The API sends UTC without a zone marker
    final hasZone = raw.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(raw);
    return Review(
      id: json['id'],
      user: json['user'],
      rating: json['rating'],
      comment: json['comment'],
      createdAt: DateTime.parse(hasZone ? raw : '${raw}Z'),
    );
  }

  /// "DC" for Demo Customer.
  String get initials => user.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0].toUpperCase()).join();
}

/// GET /api/products/{id}: the product plus its reviews and related products.
class ProductDetail {
  final Product product;
  final List<Review> reviews;
  final List<Product> related;

  const ProductDetail({required this.product, this.reviews = const [], this.related = const []});

  factory ProductDetail.fromJson(Map<String, dynamic> json) => ProductDetail(
        product: Product.fromJson(json),
        reviews: [for (final r in json['reviews'] as List? ?? []) Review.fromJson(r)],
        related: [for (final p in json['related'] as List? ?? []) Product.fromJson(p)],
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
