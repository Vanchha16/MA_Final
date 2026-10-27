import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/order.dart';

/// Checkout preview, saved addresses and placing the order.
class CheckoutService {
  final _api = ApiClient.instance;

  Future<CheckoutPreview> preview({String? coupon, DeliveryMethod delivery = DeliveryMethod.standard}) async =>
      CheckoutPreview.fromJson(await _api.get(ApiEndPoint.checkout, query: {
        'delivery': delivery.apiValue,
        'coupon': ?coupon,
      }));

  Future<Order> placeOrder({
    int? addressId,
    required DeliveryMethod delivery,
    required PaymentMethod payment,
    String? coupon,
    String? note,
  }) async =>
      Order.fromJson(await _api.post(ApiEndPoint.orders, data: {
        'address_id': ?addressId,
        'delivery_method': delivery.apiValue,
        'payment_method': payment.apiValue,
        'coupon': ?coupon,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      }));

  Future<List<Address>> addresses() async => [for (final a in await _api.get(ApiEndPoint.addresses) as List) Address.fromJson(a)];

  Future<Address> saveAddress(Address address) async => Address.fromJson(address.id == null
      ? await _api.post(ApiEndPoint.addresses, data: address.toJson())
      : await _api.put('${ApiEndPoint.addresses}/${address.id}', data: address.toJson()));

  /// Returns the addresses that are left.
  Future<List<Address>> deleteAddress(int id) async =>
      [for (final a in await _api.delete('${ApiEndPoint.addresses}/$id') as List) Address.fromJson(a)];
}
