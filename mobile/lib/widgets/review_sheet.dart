import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../api/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/catalog.dart';
import '../services/review_service.dart';
import 'confirm_dialog.dart';
import 'pill_button.dart';
import 'product_image.dart';

/// What the review sheet did: the saved review (null when it was deleted) and
/// the product's new rating summary.
class ReviewOutcome {
  final Review? review;
  final ReviewSummary summary;

  const ReviewOutcome(this.review, this.summary);

  bool get deleted => review == null;
}

/// Rate a delivered product (picked from the review previews, A): big stars
/// that pop with a word under them, quick tags, an optional comment, Post.
/// Pass [existing] to edit (or delete) the customer's review.
/// Returns null when closed without saving.
Future<ReviewOutcome?> showReviewSheet(
  BuildContext context, {
  required int productId,
  required String productName,
  String? imageUrl,
  ProductKind kind = ProductKind.figure,
  Review? existing,
  ReviewService? service,
}) =>
    showModalBottomSheet<ReviewOutcome>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => _ReviewSheet(
        productId: productId,
        productName: productName,
        imageUrl: imageUrl,
        kind: kind,
        existing: existing,
        service: service ?? ReviewService(),
      ),
    );

class _ReviewSheet extends StatefulWidget {
  final int productId;
  final String productName;
  final String? imageUrl;
  final ProductKind kind;
  final Review? existing;
  final ReviewService service;

  const _ReviewSheet({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.kind,
    required this.existing,
    required this.service,
  });

  /// How long the "Thanks" state shows before the sheet closes.
  static const thanksFor = Duration(milliseconds: 1300);

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  late int _rating = widget.existing?.rating ?? 0;
  late final Set<String> _tags = {...?widget.existing?.tags};
  late final _comment = TextEditingController(text: widget.existing?.comment ?? '');
  bool _busy = false, _done = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String get _noun => switch (widget.kind) {
        ProductKind.figure => 'figure',
        ProductKind.plush => 'plush',
        ProductKind.kit => 'model kit',
        ProductKind.tcg => 'cards',
      };

  Future<void> _post() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final (review, summary) = await widget.service.save(widget.productId, rating: _rating, comment: _comment.text, tags: _tags.toList());
      if (!mounted) return;
      setState(() => _done = true);
      await Future.delayed(_ReviewSheet.thanksFor);
      if (mounted) Navigator.of(context).pop(ReviewOutcome(review, summary));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.errors?['comment']?.toString() ?? e.errors?['rating']?.toString() ?? e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      icon: const Icon(Icons.delete_rounded, color: AppTheme.danger, size: 30),
      title: 'Delete your review?',
      message: 'Your stars and comment are removed from the product page.',
      confirmLabel: 'Delete',
      confirmKey: const Key('review_delete_confirm'),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final summary = await widget.service.delete(widget.productId);
      if (mounted) Navigator.of(context).pop(ReviewOutcome(null, summary));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final editing = widget.existing != null;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        // the form goes at once; only the Thanks fades in (no overlap)
        switchOutCurve: const Threshold(0.999),
        child: _done
            ? _Thanks(key: const Key('review_thanks'), rating: _rating, edited: editing)
            : SingleChildScrollView(
                key: const Key('review_form'),
                padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    SizedBox.square(
                      dimension: 56,
                      child: ProductImage(url: widget.imageUrl, kind: widget.kind, iconSize: 24, borderRadius: BorderRadius.circular(14)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(editing ? 'Edit your review' : 'Rate your $_noun', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(widget.productName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Center(
                    child: RatingBar.builder(
                      initialRating: _rating.toDouble(),
                      minRating: 1,
                      itemCount: 5,
                      itemSize: 46,
                      glow: false,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 3),
                      unratedColor: scheme.outlineVariant,
                      onRatingUpdate: (v) => setState(() => _rating = v.round()),
                      itemBuilder: (_, i) {
                        Widget star = const Icon(Icons.star_rounded, color: AppTheme.amber);
                        // the star just tapped pops
                        if (i == _rating - 1) {
                          star = star
                              .animate(key: ValueKey(_rating))
                              .scaleXY(begin: 1, end: 1.3, duration: 130.ms, curve: Curves.easeOut)
                              .then()
                              .scaleXY(end: 1 / 1.3, duration: 170.ms, curve: Curves.easeIn);
                        }
                        return KeyedSubtree(key: Key('review_star_${i + 1}'), child: star);
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rating == 0 ? 'Tap a star to rate' : ratingWords[_rating],
                    key: const Key('review_word'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _rating == 0 ? scheme.onSurfaceVariant : AppTheme.amber),
                  ),
                  const SizedBox(height: 18),
                  const Text('What did you like?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final MapEntry(key: tag, value: label) in reviewTags.entries)
                      FilterChip(
                        key: Key('review_tag_$tag'),
                        label: Text(label),
                        selected: _tags.contains(tag),
                        onSelected: (on) => setState(() => on ? _tags.add(tag) : _tags.remove(tag)),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: _tags.contains(tag) ? scheme.primary : scheme.outlineVariant),
                        selectedColor: scheme.primary.withValues(alpha: 0.12),
                        checkmarkColor: scheme.primary,
                        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: _tags.contains(tag) ? scheme.primary : scheme.onSurface),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('review_comment'),
                    controller: _comment,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 1000,
                    textCapitalization: TextCapitalization.sentences,
                    buildCounter: (_, {required currentLength, required isFocused, required maxLength}) =>
                        currentLength > 900 ? Text('$currentLength / $maxLength') : null,
                    decoration: InputDecoration(
                      hintText: 'Tell other collectors about it (optional)',
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, key: const Key('review_error'), style: const TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w600)),
                  ],
                  const SizedBox(height: 14),
                  PillButton(
                    key: const Key('review_post'),
                    label: editing ? 'Save changes' : 'Post review',
                    leadingIcon: Icons.send_rounded,
                    loading: _busy,
                    onPressed: _rating == 0 || _busy ? null : _post,
                  ),
                  if (editing)
                    TextButton.icon(
                      key: const Key('review_delete'),
                      onPressed: _busy ? null : _delete,
                      style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete review'),
                    ),
                ]),
              ),
      ),
    );
  }
}

class _Thanks extends StatelessWidget {
  final int rating;
  final bool edited;

  const _Thanks({super.key, required this.rating, required this.edited});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 48),
        ).animate().scale(begin: const Offset(0.4, 0.4), duration: 500.ms, curve: Curves.elasticOut),
        const SizedBox(height: 18),
        Text(edited ? 'Review updated' : 'Thanks for your review!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text('It is now on the product page for other collectors.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        RatingBarIndicator(
          rating: rating.toDouble(),
          itemCount: 5,
          itemSize: 26,
          unratedColor: scheme.outlineVariant,
          itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
        ),
      ]),
    );
  }
}
