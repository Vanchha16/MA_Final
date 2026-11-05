import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../api/api_client.dart';
import '../api/api_domain.dart';

/// A change to one order, pushed by the server (placed, paid, shipped, cancelled...).
class OrderUpdate {
  final int orderId;
  final String status;
  final String paymentStatus;

  const OrderUpdate({required this.orderId, required this.status, required this.paymentStatus});

  factory OrderUpdate.fromJson(Map<String, dynamic> json) =>
      OrderUpdate(orderId: json['order_id'] as int, status: json['status'] as String? ?? '', paymentStatus: json['payment_status'] as String? ?? '');
}

/// The Socket.IO connection to the Flask server (backend app/realtime.py).
///
/// It opens when a user signs in and closes on log out. The server pushes small
/// signals and screens load the new data with their normal API calls:
/// - [notifications]: a new message for this user (its id)
/// - [orders]: one of this user's orders changed (staff hear about every order)
/// - [adminUpdates]: staff only, a new contact message or review
class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final _notifications = StreamController<int>.broadcast();
  final _orders = StreamController<OrderUpdate>.broadcast();
  final _admin = StreamController<String>.broadcast();
  io.Socket? _socket;
  String? _token;

  Stream<int> get notifications => _notifications.stream;
  Stream<OrderUpdate> get orders => _orders.stream;
  Stream<String> get adminUpdates => _admin.stream;

  bool get connected => _socket?.connected ?? false;

  /// The server address without "/api" (the socket lives at /socket.io).
  static String get serverUrl => Uri.parse(ApiDomain.baseUrl).replace(path: '').toString();

  /// Called whenever the signed-in state changes.
  Future<void> setSignedIn(bool signedIn) => signedIn ? connect() : Future.sync(disconnect);

  /// Connects with the saved login token (again, after the token changed).
  Future<void> connect() async {
    final token = (await SharedPreferences.getInstance()).getString(ApiClient.tokenKey);
    if (token == null || (_socket != null && token == _token)) return; // already connected as this user
    disconnect();
    _token = token;
    final socket = io.io(
      serverUrl,
      // A new connection each time (not the cached one), so a new login never reuses the old token
      io.OptionBuilder().setTransports(['websocket']).setAuth({'token': token}).disableAutoConnect().enableForceNew().enableReconnection().build(),
    );
    socket
      ..on('notification', (data) => _notifications.add((data as Map)['id'] as int))
      ..on('order_updated', (data) => _orders.add(OrderUpdate.fromJson(Map<String, dynamic>.from(data as Map))))
      ..on('admin_update', (data) => _admin.add((data as Map)['kind'] as String? ?? ''))
      ..connect();
    _socket = socket;
  }

  /// A new token was saved (e.g. after a password change): reconnect with it.
  Future<void> reconnect() async {
    if (_socket != null) await connect();
  }

  void disconnect() {
    _socket
      ?..clearListeners()
      ..dispose();
    _socket = null;
    _token = null;
  }

  /// Tests push events without a server.
  @visibleForTesting
  void debugNotification(int id) => _notifications.add(id);

  @visibleForTesting
  void debugOrderUpdate(OrderUpdate update) => _orders.add(update);

  @visibleForTesting
  void debugAdminUpdate(String kind) => _admin.add(kind);
}
