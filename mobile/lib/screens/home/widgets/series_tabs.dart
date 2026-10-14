import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/catalog.dart';

/// Horizontal "All, One Piece, Pokemon, ..." pills (Figma: Series Chips).
/// The selected one is solid blue; null means "All".
class SeriesTabs extends StatelessWidget {
  final List<Series> series;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  const SeriesTabs({super.key, required this.series, required this.selectedId, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final items = <(int?, String)>[(null, 'All'), for (final s in series) (s.id, s.name)];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, name) = items[i];
          return _Pill(key: Key('series_${id ?? 'all'}'), label: name, selected: id == selectedId, onTap: () => onSelected(id));
        },
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = selected ? AppTheme.primaryDark : (dark ? scheme.surfaceContainerHigh : Colors.white);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: bg,
        shape: StadiumBorder(
          side: selected ? BorderSide.none : BorderSide(color: scheme.primary.withValues(alpha: dark ? 0.30 : 0.18)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
