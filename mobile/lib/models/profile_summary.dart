import 'user.dart';

/// Loyalty tier: Bronze -> Silver (500 pts) -> Gold (2,000) -> Platinum (5,000).
class Tier {
  final String name;
  final String? nextName;
  final int pointsToNext;

  /// 0..1 progress towards [nextName].
  final double progress;

  const Tier({required this.name, this.nextName, required this.pointsToNext, required this.progress});

  factory Tier.fromJson(Map<String, dynamic> json) => Tier(
        name: json['name'],
        nextName: json['next_name'],
        pointsToNext: json['points_to_next'],
        progress: (json['progress'] as num).toDouble(),
      );
}

/// Everything the Profile tab shows, from GET /api/profile/summary.
class ProfileSummary {
  final User user;
  final int orders, wishlist, reviews;
  final int toPay, toShip, toReceive, toReview;
  final int points;
  final Tier tier;

  const ProfileSummary({
    required this.user,
    required this.orders,
    required this.wishlist,
    required this.reviews,
    required this.toPay,
    required this.toShip,
    required this.toReceive,
    required this.toReview,
    required this.points,
    required this.tier,
  });

  factory ProfileSummary.fromJson(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>;
    final status = json['order_status'] as Map<String, dynamic>;
    return ProfileSummary(
      user: User.fromJson(json['user']),
      orders: stats['orders'],
      wishlist: stats['wishlist'],
      reviews: stats['reviews'],
      toPay: status['to_pay'],
      toShip: status['to_ship'],
      toReceive: status['to_receive'],
      toReview: status['to_review'],
      points: json['points'],
      tier: Tier.fromJson(json['tier']),
    );
  }
}
