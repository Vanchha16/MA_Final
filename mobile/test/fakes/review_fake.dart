import 'package:ecommerce_app/api/api_client.dart';
import 'package:ecommerce_app/models/catalog.dart';
import 'package:ecommerce_app/services/review_service.dart';

/// Reviews in memory, following the backend rules (one per customer and product,
/// own review first, filters by stars and comments).
class FakeReviewService extends ReviewService {
  final List<Review> all = [
    Review(id: 1, user: 'Sok Dara', rating: 5, comment: 'Box arrived perfect.', tags: const ['packaging'], createdAt: DateTime.now().subtract(const Duration(days: 3))),
    Review(id: 2, user: 'Chan Sreyneang', rating: 4, comment: 'Great paint work.', tags: const ['quality'], createdAt: DateTime.now().subtract(const Duration(days: 7))),
    Review(id: 3, user: 'Vuthy Rith', rating: 5, createdAt: DateTime.now().subtract(const Duration(days: 20))),
  ];
  List<ToReviewItem> pending = [];
  final saved = <(int, int, String?, List<String>)>[];
  final deleted = <int>[];
  bool failSave = false;

  ReviewSummary _summary() => ReviewSummary(
        rating: all.isEmpty ? 0 : all.map((r) => r.rating).reduce((a, b) => a + b) / all.length,
        count: all.length,
        withComment: all.where((r) => r.hasComment).length,
        stars: {for (var n = 5; n >= 1; n--) n: all.where((r) => r.rating == n).length},
      );

  @override
  Future<ReviewPage> reviews(int productId, {int? rating, bool withComment = false, int page = 1, int perPage = 20}) async {
    final items = [
      ...all.where((r) => r.isMine),
      ...all.where((r) => !r.isMine),
    ].where((r) => (rating == null || r.rating == rating) && (!withComment || r.hasComment)).toList();
    return ReviewPage(summary: _summary(), items: items, total: items.length);
  }

  @override
  Future<(Review, ReviewSummary)> save(int productId, {required int rating, String? comment, List<String> tags = const []}) async {
    if (failSave) throw ApiException('Validation failed', statusCode: 422, errors: {'comment': 'Keep it under 1000 characters'});
    saved.add((productId, rating, (comment ?? '').trim().isEmpty ? null : comment!.trim(), tags));
    final had = all.indexWhere((r) => r.isMine);
    final review = Review(
      id: had >= 0 ? all[had].id : 99,
      productId: productId,
      user: 'Demo Customer',
      rating: rating,
      comment: (comment ?? '').trim().isEmpty ? null : comment!.trim(),
      tags: tags,
      createdAt: DateTime.now(),
      edited: had >= 0,
      isMine: true,
    );
    if (had >= 0) {
      all[had] = review;
    } else {
      all.insert(0, review);
    }
    pending.removeWhere((p) => p.product.id == productId);
    return (review, _summary());
  }

  @override
  Future<ReviewSummary> delete(int productId) async {
    deleted.add(productId);
    all.removeWhere((r) => r.isMine);
    return _summary();
  }

  @override
  Future<List<ToReviewItem>> toReview() async => [...pending];
}
