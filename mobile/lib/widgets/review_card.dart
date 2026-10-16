import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../core/theme/app_theme.dart';
import '../models/catalog.dart';

const _avatarColors = [AppTheme.primaryDark, Color(0xFF7C3AED), AppTheme.success, AppTheme.coral, Color(0xFFB45309), Color(0xFF0891B2)];

/// One review: who (a verified buyer), when, stars, comment and tags.
/// The customer's own review is outlined and can be edited with [onEdit].
class ReviewCard extends StatelessWidget {
  final Review review;
  final VoidCallback? onEdit;

  /// Lines of the comment to show (null = all).
  final int? maxLines;

  const ReviewCard({super.key, required this.review, this.onEdit, this.maxLines});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = _avatarColors[review.user.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];
    final mine = review.isMine;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: mine ? Border.all(color: scheme.primary.withValues(alpha: 0.55), width: 1.5) : null,
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: dark ? 0.3 : 0.15),
            child: Text(review.initials, style: TextStyle(color: dark ? Colors.white : color, fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(mine ? 'You' : review.user, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold))),
                const SizedBox(width: 5),
                const Tooltip(message: 'Verified buyer', child: Icon(Icons.verified_rounded, size: 15, color: AppTheme.success)),
              ]),
              Text(
                '${timeago.format(review.createdAt)}${review.edited ? ' · edited' : ''}',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ]),
          ),
          RatingBarIndicator(
            rating: review.rating.toDouble(),
            itemCount: 5,
            itemSize: 15,
            unratedColor: scheme.outlineVariant,
            itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
          ),
        ]),
        if (review.hasComment) ...[
          const SizedBox(height: 8),
          Text(
            review.comment!,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
          ),
        ],
        if (review.tags.isNotEmpty || (mine && onEdit != null)) ...[
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final t in review.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: scheme.surfaceContainerHighest.withValues(alpha: dark ? 1 : 0.6), borderRadius: BorderRadius.circular(10)),
                    child: Text(reviewTags[t]!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
                  ),
              ]),
            ),
            if (mine && onEdit != null)
              TextButton.icon(
                key: const Key('review_edit_mine'),
                onPressed: onEdit,
                style: TextButton.styleFrom(minimumSize: const Size(0, 32), padding: const EdgeInsets.symmetric(horizontal: 10), visualDensity: VisualDensity.compact),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit'),
              ),
          ]),
        ],
      ]),
    );
  }
}
