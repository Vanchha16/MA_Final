import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin.dart';
import '../models/catalog.dart';

/// The shop owner's calls (/api/admin). Every one needs an admin login.
/// Lists ask for up to 100 rows, plenty for this shop.
class AdminService {
  final _api = ApiClient.instance;
  static const _base = ApiConstants.admin;

  Future<AdminStats> stats() async => AdminStats.fromJson(await _api.get('$_base/stats'));

  Future<List<ActivityEvent>> activity({int limit = 20}) async =>
      [for (final e in await _api.get('$_base/activity', query: {'limit': limit}) as List) ActivityEvent.fromJson(e)];

  // ---------- Orders ----------

  Future<List<AdminOrder>> orders() async =>
      [for (final o in (await _api.get('$_base/orders', query: {'per_page': 100}))['items'] as List) AdminOrder.fromJson(o)];

  Future<AdminOrder> order(int id) async => AdminOrder.fromJson(await _api.get('$_base/orders/$id'));

  /// confirmed, shipped, delivered or cancelled. The customer gets a notification.
  Future<AdminOrder> setOrderStatus(int orderId, String status) async =>
      AdminOrder.fromJson(await _api.put('$_base/orders/$orderId/status', data: {'status': status}));

  // ---------- Products ----------

  Future<List<AdminProduct>> products() async =>
      [for (final p in (await _api.get('$_base/products', query: {'per_page': 100}))['items'] as List) AdminProduct.fromJson(p)];

  Future<AdminProduct> product(int id) async => AdminProduct.fromJson(await _api.get('$_base/products/$id'));

  /// Creates when [id] is null; otherwise sends only [fields] (name, category_id, price, ...).
  Future<AdminProduct> saveProduct(Map<String, dynamic> fields, {int? id}) async => AdminProduct.fromJson(
        id == null ? await _api.post('$_base/products', data: fields) : await _api.put('$_base/products/$id', data: fields),
      );

  Future<void> setStock(int productId, int stock) => _api.put('$_base/products/$productId', data: {'stock': stock});

  Future<AdminProduct> setInShop(int productId, bool inShop) async =>
      AdminProduct.fromJson(await _api.put('$_base/products/$productId', data: {'is_active': inShop}));

  Future<AdminProduct> uploadPhoto(int productId, XFile file) async {
    final form = FormData.fromMap({'file': MultipartFile.fromBytes(await file.readAsBytes(), filename: file.name)});
    return AdminProduct.fromJson(await _api.post('$_base/products/$productId/images', data: form));
  }

  Future<AdminProduct> deletePhoto(int productId, int imageId) async =>
      AdminProduct.fromJson(await _api.delete('$_base/products/$productId/images/$imageId'));

  Future<List<Series>> series() async => [for (final s in await _api.get(ApiConstants.series) as List) Series.fromJson(s)];

  // ---------- Categories ----------

  Future<List<AdminCategory>> categories() async => [for (final c in await _api.get('$_base/categories') as List) AdminCategory.fromJson(c)];

  Future<AdminCategory> saveCategory({int? id, required String name, String? description}) async {
    final data = {'name': name, 'description': description};
    return AdminCategory.fromJson(id == null ? await _api.post('$_base/categories', data: data) : await _api.put('$_base/categories/$id', data: data));
  }

  Future<void> deleteCategory(int id) => _api.delete('$_base/categories/$id');

  // ---------- Customers ----------

  Future<List<Customer>> customers() async =>
      [for (final c in (await _api.get('$_base/customers', query: {'per_page': 100}))['items'] as List) Customer.fromJson(c)];

  Future<Customer> customer(int id) async => Customer.fromJson(await _api.get('$_base/customers/$id'));

  /// Blocking signs the customer out everywhere.
  Future<Customer> setCustomerActive(int id, bool active) async => Customer.fromJson(await _api.put('$_base/customers/$id', data: {'is_active': active}));

  // ---------- Contact messages ----------

  Future<List<AdminMessage>> messages() async =>
      [for (final m in (await _api.get('$_base/contact-messages', query: {'per_page': 100}))['items'] as List) AdminMessage.fromJson(m)];

  Future<void> reply(int messageId, String text) => _api.post('$_base/contact-messages/$messageId/reply', data: {'reply': text});
}
