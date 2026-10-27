import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../services/review_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/review_card.dart';
import '../../widgets/review_sheet.dart';

/// All reviews of a product (picked from the review previews, A): the score,
/// a 5-to-1 star chart, filter chips (All, each star, With comments) and the
/// reviews, the customer's own first. Pops with true when the customer
/// changed their review, so the product page can refresh.
class ReviewsScreen extends StatefulWidget {
  final Product product;

  /// The customer may write a review (the product was delivered to them).
  final bool canReview;
  final ReviewService? service;

  const ReviewsScreen({super.key, required this.product, this.canReview = false, this.service});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

/// A filter chip: null rating = all; withComment = only written ones.
typedef _Filter = ({int? rating, bool withComment});

class _ReviewsScreenState extends State<ReviewsScreen> {
  late final ReviewService _service = widget.service ?? ReviewService();
  final _scroll = ScrollController();
  _Filter _filter = (rating: null, withComment: false);
  ReviewSummary? _summary;
  final List<Review> _items = [];
  int _page = 1;
  bool _hasMore = false, _loading = false, _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.reviews(widget.product.id, rating: _filter.rating, withComment: _filter.withComment);
      if (!mounted) return;
      setState(() {
        _summary = page.summary;
        _items
          ..clear()
          ..addAll(page.items);
        _page = 1;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loading) return;
    setState(() => _loading = true);
    try {
      final page = await _service.reviews(widget.product.id, rating: _filter.rating, withComment: _filter.withComment, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _page = page.page;
        _hasMore = page.hasMore;
      });
    } on ApiException catch (_) {
      // keep what we have; scrolling again retries
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(_Filter f) {
    if (f == _filter) return;
    setState(() => _filter = f);
    _load();
  }

  Future<void> _write([Review? existing]) async {
    final p = widget.product;
    final outcome = await showReviewSheet(context,
        productId: p.id, productName: p.name, imageUrl: p.imageUrl, kind: p.category.kind, existing: existing, service: _service);
    if (outcome == null || !mounted) return;
    _changed = true;
    await _load();
    if (mounted) {
      if (outcome.deleted) {
        AppToast.removed(context, 'Review deleted');
      } else {
        AppToast.success(context, existing == null ? 'Review posted' : 'Review updated');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = _summary;
    final mine = _items.where((r) => r.isMine).firstOrNull;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(children: [
                    const CircleBackButton(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Reviews', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        Text(widget.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                ),
                if (s == null && _error != null)
                  Padding(padding: const EdgeInsets.all(20), child: Column(children: [ErrorBanner(message: _error!), TextButton(onPressed: _load, child: const Text('Try again'))]))
                else if (s == null)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else ...[
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _SummaryCard(summary: s, selected: _filter.rating)),
                  if (widget.canReview && mine == null && _filter.rating == null && !_filter.withComment)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: OutlinedButton.icon(
                        key: const Key('reviews_write'),
                        onPressed: () => _write(),
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46), shape: const StadiumBorder()),
                        icon: const Icon(Icons.star_rounded, color: AppTheme.amber),
                        label: const Text('Rate this product'),
                      ),
                    ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      for (final (key, label, f) in <(String, String, _Filter)>[
                        ('all', 'All  ${s.count}', (rating: null, withComment: false)),
                        for (var n = 5; n >= 1; n--) ('$n', '$n ${n == 1 ? 'star' : 'stars'}  ${s.starCount(n)}', (rating: n, withComment: false)),
                        ('comments', 'With comments  ${s.withComment}', (rating: null, withComment: true)),
                      ]) ...[
                        ChoiceChip(
                          key: Key('reviews_filter_$key'),
                          label: Text(label),
                          selected: _filter == f,
                          showCheckmark: false,
                          onSelected: (_) => _pick(f),
                          shape: const StadiumBorder(),
                          side: BorderSide(color: _filter == f ? scheme.primary : scheme.outlineVariant),
                          selectedColor: scheme.primary,
                          labelStyle: TextStyle(fontWeight: FontWeight.w600, color: _filter == f ? scheme.onPrimary : scheme.onSurface),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (_items.isEmpty && !_loading)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(children: [
                        Icon(Icons.rate_review_outlined, size: 48, color: scheme.onSurfaceVariant),
                        const SizedBox(height: 10),
                        Text(
                          s.count == 0 ? 'No reviews yet. Collectors can rate it once it arrives.' : 'No reviews match this filter.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ]),
                    ),
                  for (final r in _items)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                      child: ReviewCard(key: Key('review_${r.id}'), review: r, onEdit: r.isMine ? () => _write(r) : null),
                    ),
                  if (_loading && _items.isNotEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2.5))),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The score, its stars and count, and one bar per star level.
class _SummaryCard extends StatelessWidget {
  final ReviewSummary summary;
  final int? selected;

  const _SummaryCard({required this.summary, this.selected});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final s = summary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Row(children: [
        Column(children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: s.rating),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Text(v.toStringAsFixed(1), key: const Key('reviews_score'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
          ),
          const SizedBox(height: 6),
          RatingBarIndicator(
            rating: s.rating,
            itemCount: 5,
            itemSize: 16,
            unratedColor: scheme.outlineVariant,
            itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
          ),
          const SizedBox(height: 4),
          Text('${s.count} ${s.count == 1 ? 'review' : 'reviews'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(width: 18),
        Expanded(
          child: Column(children: [
            for (var n = 5; n >= 1; n--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(children: [
                  SizedBox(
                    width: 12,
                    child: Text('$n', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected == n ? scheme.primary : scheme.onSurfaceVariant)),
                  ),
                  const Icon(Icons.star_rounded, size: 13, color: AppTheme.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: s.share(n)),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(value: v, minHeight: 7, color: AppTheme.amber, backgroundColor: scheme.surfaceContainerHighest),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 34,
                    child: Text('${(s.share(n) * 100).round()}%', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}
