class User {
  final int id;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String role;

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.role = 'customer',
  });

  /// Shop owner: everything, including staff, promo codes and blocking customers.
  bool get isAdmin => role == 'admin';

  /// Shop team (staff or owner): opens the admin area instead of the shop.
  bool get isStaff => role == 'staff' || role == 'admin';

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        fullName: json['full_name'],
        email: json['email'],
        phone: json['phone'],
        avatarUrl: json['avatar_url'],
        role: json['role'] ?? 'customer',
      );
}
