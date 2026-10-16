import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/catalog.dart';
import '../services/review_service.dart';
import 'error_banner.dart';
import 'product_image.dart';
import 'review_sheet.dart';

/// Profile > To review: delivered products not rated yet, each with Rate it.
/// Returns true when at least one review was posted.
Future<bool?> showToReviewSheet(BuildContext context, {ReviewService? service}) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ToReviewSheet(service: service ?? ReviewService()),
    );

class _ToReviewSheet extends StatefulWidget {
  final ReviewService service;

  const _ToReviewSheet({required this.service});

  @override
  State<_ToReviewSheet> createState() => _ToReviewSheetState();
}

class _ToReviewSheetState extends State<_ToReviewSheet> {
  List<ToReviewItem>? _items;
  final Map<int, int> _rated = {}; // product id -> stars, posted from this sheet
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await widget.service.toReview();
      if (mounted) setState(() => _items = items);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _rate(ToReviewItem item) async {
    final p = item.product;
    final outcome = await showReviewSheet(context,
        productId: p.id, productName: p.name, imageUrl: p.imageUrl, kind: p.category.kind, service: widget.service);
    if (outcome?.review != null && mounted) setState(() => _rated[p.id] = outcome!.review!.rating);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    final waiting = items?.where((i) => !_rated.containsKey(i.product.id)).length ?? 0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_rated.isNotEmpty);
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Expanded(child: Text('To review', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
              if (items != null && waiting > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: AppTheme.coral.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(20)),
                  child: Text('$waiting waiting', style: const TextStyle(color: AppTheme.coral, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ]),
          ),
          if (_error != null && items == null)
            Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: Column(children: [ErrorBanner(message: _error!), TextButton(onPressed: _load, child: const Text('Try again'))]))
          else if (items == null)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 36),
              child: Column(children: [
                Icon(Icons.task_alt_rounded, size: 48, color: AppTheme.success.withValues(alpha: 0.8)),
                const SizedBox(height: 10),
                const Text('All caught up!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text('Items you receive show up here so you can rate them.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
              ]),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => Divider(height: 20, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final p = item.product;
                  final stars = _rated[p.id];
                  return Row(key: Key('to_review_${p.id}'), children: [
                    SizedBox.square(dimension: 56, child: ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 24, borderRadius: BorderRadius.circular(12))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.3)),
                        if (stars == null)
                          Text(item.orderNumber, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
                        else
                          RatingBarIndicator(
                            rating: stars.toDouble(),
                            itemCount: 5,
                            itemSize: 15,
                            unratedColor: scheme.outlineVariant,
                            itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
                          ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    if (stars == null)
                      FilledButton.icon(
                        key: Key('to_review_rate_${p.id}'),
                        onPressed: () => _rate(item),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          shape: const StadiumBorder(),
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.star_rounded, size: 18),
                        label: const Text('Rate it'),
                      )
                    else
                      const Icon(Icons.check_circle_rounded, color: AppTheme.success),
                  ]);
                },
              ),
            ),
        ]),
      ),
    );
  }
}
