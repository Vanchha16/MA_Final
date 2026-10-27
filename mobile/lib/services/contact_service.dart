import '../api/api_end_point.dart';
import '../api/api_client.dart';

/// What a Contact message is about (the API's topic values).
enum ContactTopic {
  order,
  payment,
  product,
  other;

  /// Order and payment questions can name one of the customer's orders.
  bool get aboutAnOrder => this == order || this == payment;
}

class ContactService {
  final _api = ApiClient.instance;

  /// Sends a message from the Contact screen; the reply comes back as a notification.
  Future<void> send({required ContactTopic topic, required String message, int? orderId}) async {
    await _api.post(ApiEndPoint.contact, data: {
      'topic': topic.name,
      'message': message,
      if (orderId != null && topic.aboutAnOrder) 'order_id': orderId,
    });
  }
}
