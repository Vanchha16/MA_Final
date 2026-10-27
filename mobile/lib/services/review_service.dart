import '../api/api_end_point.dart';
import '../api/api_client.dart';
import '../models/catalog.dart';

/// Star ratings and reviews. Reading needs no login; writing is for products
/// that were delivered to the customer (posting again edits their review).
class ReviewService {
  final _api = ApiClient.instance;

  String _path(int productId) => '${ApiEndPoint.products}/$productId/reviews';

  /// One page, newest first (the customer's own review first). [rating] keeps one star level.
  Future<ReviewPage> reviews(int productId, {int? rating, bool withComment = false, int page = 1, int perPage = 20}) async =>
      ReviewPage.fromJson(await _api.get(_path(productId), query: {
        'page': page,
        'per_page': perPage,
        'rating': ?rating,
        if (withComment) 'with_comment': 1,
      }));

  /// Creates or edits the customer's review; returns it and the product's new summary.
  Future<(Review, ReviewSummary)> save(int productId, {required int rating, String? comment, List<String> tags = const []}) async {
    final data = await _api.post(_path(productId), data: {
      'rating': rating,
      'comment': (comment ?? '').trim().isEmpty ? null : comment!.trim(),
      'tags': tags,
    });
    return (Review.fromJson(data['review']), ReviewSummary.fromJson(data['summary']));
  }

  Future<ReviewSummary> delete(int productId) async => ReviewSummary.fromJson((await _api.delete('${_path(productId)}/mine'))['summary']);

  /// Delivered products the customer hasn't rated yet.
  Future<List<ToReviewItem>> toReview() async => [for (final t in await _api.get(ApiEndPoint.toReview) as List) ToReviewItem.fromJson(t)];
}
