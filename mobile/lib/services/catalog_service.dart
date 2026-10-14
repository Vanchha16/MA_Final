import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/catalog.dart';

class CatalogService {
  final _api = ApiClient.instance;

  Future<List<Category>> categories() async =>
      [for (final c in await _api.get(ApiConstants.categories) as List) Category.fromJson(c)];

  Future<List<Series>> series() async =>
      [for (final s in await _api.get(ApiConstants.series) as List) Series.fromJson(s)];

  Future<ProductPage> products(ProductQuery query, {int page = 1, int perPage = 10}) async =>
      ProductPage.fromJson(await _api.get(ApiConstants.products, query: query.toParams(page: page, perPage: perPage)));

  /// Featured products for the Home banner.
  Future<List<Product>> featured({int limit = 5}) async {
    final data = await _api.get(ApiConstants.products, query: {'featured': 1, 'per_page': limit});
    return ProductPage.fromJson(data).items;
  }
}
