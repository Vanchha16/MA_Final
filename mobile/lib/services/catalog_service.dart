import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/catalog.dart';

class CatalogService {
  final _api = ApiClient.instance;

  Future<List<Category>> categories() async =>
      [for (final c in await _api.get(ApiConstants.categories) as List) Category.fromJson(c)];

  Future<List<Series>> series() async =>
      [for (final s in await _api.get(ApiConstants.series) as List) Series.fromJson(s)];

  Future<List<String>> brands() async => [for (final b in await _api.get(ApiConstants.brands) as List) b as String];

  Future<ProductDetail> product(int id) async =>
      ProductDetail.fromJson(await _api.get('${ApiConstants.products}/$id'));

  Future<SearchSuggestions> suggestions(String q) async =>
      SearchSuggestions.fromJson(await _api.get(ApiConstants.searchSuggestions, query: {'q': q}));

  /// Featured products, for "Trending now" on Search.
  Future<List<Product>> trending({int limit = 5}) async =>
      (await products(const ProductQuery(), perPage: limit, featuredOnly: true)).items;

  /// How many products match, for the filter's "Show 12 results".
  Future<int> count(ProductQuery query) async => (await products(query, perPage: 1)).total;

  Future<ProductPage> products(ProductQuery query, {int page = 1, int perPage = 10, bool featuredOnly = false}) async =>
      ProductPage.fromJson(await _api.get(
        ApiConstants.products,
        query: {...query.toParams(page: page, perPage: perPage), if (featuredOnly) 'featured': 1},
      ));
}
