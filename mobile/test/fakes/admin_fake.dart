import 'package:ecommerce_app/core/network/api_client.dart';
import 'package:ecommerce_app/models/admin.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/models/order.dart';
import 'package:ecommerce_app/services/admin_service.dart';
import 'package:image_picker/image_picker.dart';

const _figures = Category(id: 1, name: 'Scale Figures', slug: 'scale-figures', productCount: 2);

AdminOrder adminOrder(int id, String status, List<String> next, {PaymentMethod pay = PaymentMethod.cod, String paid = 'unpaid', double total = 87}) => AdminOrder(
      order: Order(
        id: id,
        number: 'AWS-2026101$id-000$id',
        status: status,
        paymentMethod: pay,
        paymentStatus: paid,
        subtotal: total,
        total: total,
        itemCount: 1,
        shippingAddress: '#24 St. 271, Chamkar Mon, Phnom Penh',
        lines: const [OrderLine(productId: 1, name: 'Luffy Gear 5 Figure', unitPrice: 87, quantity: 1)],
      ),
      customerId: 2,
      customerName: 'Demo Customer',
      customerEmail: 'demo@shop.com',
      phone: '012345678',
      nextStatuses: next,
    );

/// Everything the admin screens call, in memory. Order steps follow the backend rules.
class FakeAdminService extends AdminService {
  AdminStats stats_ = const AdminStats(revenue: 1053, weekRevenue: 127, week: [20, 40, 0, 60, 30, 40, 70], ordersToHandle: 4, lowStock: 5, openMessages: 2);
  List<ActivityEvent> events = [
    ActivityEvent(id: 'paid-3', kind: ActivityKind.paid, at: DateTime.now().toUtc(), title: 'Payment received', message: 'Chan paid \$27.00 by KHQR',
        action: ActivityAction.ship, orderId: 3, status: 'confirmed'),
    ActivityEvent(id: 'message-1', kind: ActivityKind.message, at: DateTime.now().toUtc(), title: 'New message', message: '"Posters?"',
        action: ActivityAction.reply, messageId: 1, status: 'open'),
    ActivityEvent(id: 'order-1', kind: ActivityKind.order, at: DateTime.now().toUtc(), title: 'New order AWS-1', message: 'Demo · \$87.00 · cash',
        action: ActivityAction.confirm, orderId: 1, status: 'pending'),
    ActivityEvent(id: 'stock-7', kind: ActivityKind.soldOut, at: DateTime.now().toUtc(), title: 'Sold out', message: 'Makima has 0 left',
        action: ActivityAction.restock, productId: 7),
    ActivityEvent(id: 'order-9', kind: ActivityKind.order, at: DateTime.now().toUtc(), title: 'New order AWS-9', message: 'Demo · \$12.00 · KHQR', status: 'delivered'),
  ];
  bool fail = false;
  final statuses = <(int, String)>[];
  final replies = <(int, String)>[];
  final stock = <(int, int)>[];
  final savedProducts = <Map<String, dynamic>>[];
  final uploads = <int>[];
  int loads = 0;

  List<AdminOrder> orders_ = [
    adminOrder(1, 'pending', ['confirmed', 'cancelled']),
    adminOrder(2, 'confirmed', ['shipped', 'cancelled'], pay: PaymentMethod.khqr, paid: 'paid', total: 13),
    adminOrder(3, 'confirmed', ['shipped', 'cancelled'], pay: PaymentMethod.khqr, paid: 'paid', total: 27),
    adminOrder(5, 'shipped', ['delivered']),
    adminOrder(4, 'delivered', [], pay: PaymentMethod.khqr, paid: 'paid', total: 50),
  ];
  List<AdminProduct> products_ = [
    const AdminProduct(product: Product(id: 7, name: 'F:NEX Makima 1/7', price: 245, stock: 0, category: _figures)),
    const AdminProduct(product: Product(id: 8, name: 'Satoru Gojo 1/7', brand: 'Bandai', price: 159, discountPrice: 149, stock: 2, category: _figures)),
    const AdminProduct(product: Product(id: 9, name: 'Old Keychain', price: 5, stock: 10, category: _figures), isActive: false),
  ];
  List<AdminCategory> categories_ = [const AdminCategory(id: 1, name: 'Scale Figures', productCount: 2), const AdminCategory(id: 5, name: 'Model Kits')];
  List<Customer> customers_ = [
    const Customer(id: 2, fullName: 'Demo Customer', email: 'demo@shop.com', orderCount: 4, totalSpent: 150),
    const Customer(id: 3, fullName: 'Spam Bot', email: 'bot@spam.test', isActive: false),
  ];
  List<AdminMessage> messages_ = [
    AdminMessage(id: 1, topic: 'order', message: 'When will my Luffy figure arrive?', status: 'open', customerName: 'Demo Customer', orderNumber: 'AWS-20261011-0001', createdAt: DateTime.now().toUtc()),
    AdminMessage(id: 2, topic: 'payment', message: 'I paid twice.', status: 'answered', reply: 'Refunded!', customerName: 'Demo Customer', createdAt: DateTime.now().toUtc()),
  ];

  static const _steps = {'pending': ['confirmed', 'cancelled'], 'confirmed': ['shipped', 'cancelled'], 'shipped': ['delivered'], 'delivered': <String>[], 'cancelled': <String>[]};

  void _maybeFail() {
    if (fail) throw ApiException('Cannot connect to server. Check your internet connection.');
  }

  @override
  Future<AdminStats> stats() async {
    loads++;
    _maybeFail();
    return stats_;
  }

  @override
  Future<List<ActivityEvent>> activity({int limit = 20}) async {
    _maybeFail();
    return [...events];
  }

  @override
  Future<List<AdminOrder>> orders() async {
    _maybeFail();
    return [...orders_];
  }

  @override
  Future<AdminOrder> order(int id) async => orders_.firstWhere((o) => o.order.id == id);

  final refunds = <int>[];

  @override
  Future<AdminOrder> markRefunded(int orderId) async {
    refunds.add(orderId);
    final i = orders_.indexWhere((o) => o.order.id == orderId);
    final o = orders_[i];
    return orders_[i] = AdminOrder(order: o.order.copyWith(paymentStatus: 'refunded'), customerId: o.customerId, customerName: o.customerName,
        customerEmail: o.customerEmail, phone: o.phone, nextStatuses: o.nextStatuses);
  }

  @override
  Future<AdminOrder> setOrderStatus(int orderId, String status) async {
    statuses.add((orderId, status));
    final i = orders_.indexWhere((o) => o.order.id == orderId);
    if (i < 0) return adminOrder(orderId, status, _steps[status] ?? const []);
    final o = orders_[i];
    if (!o.nextStatuses.contains(status)) throw ApiException('A ${o.order.status} order cannot be marked $status', statusCode: 409);
    final moved = AdminOrder(order: o.order.copyWith(status: status), customerId: o.customerId, customerName: o.customerName, customerEmail: o.customerEmail, phone: o.phone, nextStatuses: _steps[status]!);
    orders_[i] = moved;
    return moved;
  }

  @override
  Future<List<AdminProduct>> products() async {
    _maybeFail();
    return [...products_];
  }

  @override
  Future<AdminProduct> saveProduct(Map<String, dynamic> fields, {int? id}) async {
    if ((fields['name'] as String? ?? '').isEmpty) throw ApiException('Validation failed', statusCode: 422, errors: {'name': 'name is required'});
    savedProducts.add({...fields, 'id': id});
    return AdminProduct(product: Product(id: id ?? 99, name: fields['name'], price: (fields['price'] as num).toDouble(), stock: fields['stock'], category: _figures), isActive: fields['is_active'] ?? true);
  }

  @override
  Future<AdminProduct> setInShop(int productId, bool inShop) async {
    final i = products_.indexWhere((p) => p.product.id == productId);
    products_[i] = AdminProduct(product: products_[i].product, isActive: inShop, photos: products_[i].photos);
    return products_[i];
  }

  @override
  Future<void> setStock(int productId, int stock) async => this.stock.add((productId, stock));

  @override
  Future<AdminProduct> uploadPhoto(int productId, XFile file) async {
    uploads.add(productId);
    return AdminProduct(product: Product(id: productId, name: 'x', price: 1, stock: 1, category: _figures), photos: [ProductPhoto(id: uploads.length, url: 'http://x/$productId.webp', isPrimary: uploads.length == 1)]);
  }

  @override
  Future<List<Series>> series() async => const [Series(id: 1, name: 'One Piece', slug: 'one-piece')];

  @override
  Future<List<AdminCategory>> categories() async => [...categories_];

  @override
  Future<AdminCategory> saveCategory({int? id, required String name, String? description}) async {
    if (name.isEmpty) throw ApiException('Validation failed', statusCode: 422, errors: {'name': 'name is required'});
    final c = AdminCategory(id: id ?? 50 + categories_.length, name: name, description: description);
    categories_ = [for (final x in categories_) if (x.id != c.id) x, c];
    return c;
  }

  @override
  Future<void> deleteCategory(int id) async => categories_.removeWhere((c) => c.id == id);

  @override
  Future<List<Customer>> customers() async => [...customers_];

  @override
  Future<Customer> customer(int id) async => customers_.firstWhere((c) => c.id == id);

  @override
  Future<Customer> setCustomerActive(int id, bool active) async {
    final i = customers_.indexWhere((c) => c.id == id);
    final c = customers_[i];
    return customers_[i] = Customer(id: c.id, fullName: c.fullName, email: c.email, isActive: active, orderCount: c.orderCount, totalSpent: c.totalSpent);
  }

  List<StaffMember> staff_ = [
    const StaffMember(id: 1, fullName: 'Admin', email: 'admin@shop.com', role: 'admin'),
    const StaffMember(id: 4, fullName: 'Shop Staff', email: 'staff@shop.com', phone: '012345678'),
  ];
  final staffChanges = <(int, Map<String, dynamic>)>[];

  @override
  Future<List<StaffMember>> staff() async => [...staff_];

  @override
  Future<StaffMember> addStaff({required String fullName, required String email, required String password, String? phone, String role = 'staff'}) async {
    if (password.length < 8) throw ApiException('Validation failed', statusCode: 422, errors: {'password': 'Password must be at least 8 characters'});
    final s = StaffMember(id: 10 + staff_.length, fullName: fullName, email: email, phone: phone, role: role);
    staff_ = [...staff_, s];
    return s;
  }

  @override
  Future<StaffMember> updateStaff(int id, Map<String, dynamic> changes) async {
    staffChanges.add((id, changes));
    final i = staff_.indexWhere((s) => s.id == id);
    final s = staff_[i];
    return staff_[i] = StaffMember(id: id, fullName: changes['full_name'] ?? s.fullName, email: s.email, phone: changes.containsKey('phone') ? changes['phone'] : s.phone,
        role: changes['role'] ?? s.role, isActive: changes['is_active'] ?? s.isActive);
  }

  @override
  Future<List<AdminMessage>> messages() async => [...messages_];

  @override
  Future<void> reply(int messageId, String text) async {
    replies.add((messageId, text));
    messages_ = [
      for (final m in messages_)
        m.id == messageId ? AdminMessage(id: m.id, topic: m.topic, message: m.message, status: 'answered', reply: text, customerName: m.customerName, createdAt: m.createdAt) : m,
    ];
  }
}
