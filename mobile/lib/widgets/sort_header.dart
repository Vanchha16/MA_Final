import 'package:flutter/material.dart';

import '../models/catalog.dart';

/// List title (with an optional item count) and a sort menu on the right.
class SortHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final ProductSort sort;
  final ValueChanged<ProductSort> onSort;

  /// Shown between the title and the sort menu, e.g. a grid/list toggle.
  final List<Widget> actions;

  const SortHeader({super.key, required this.title, this.subtitle, required this.sort, required this.onSort, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
        ...actions,
        PopupMenuButton<ProductSort>(
          key: const Key('home_sort'),
          tooltip: 'Sort',
          initialValue: sort,
          onSelected: onSort,
          itemBuilder: (_) => [for (final s in ProductSort.values) PopupMenuItem(value: s, child: Text(s.label))],
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 10, 6),
            decoration: BoxDecoration(
              color: dark ? scheme.surfaceContainerHigh : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: scheme.primary.withValues(alpha: dark ? 0.3 : 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sort.short, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                Icon(Icons.swap_vert_rounded, size: 18, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

