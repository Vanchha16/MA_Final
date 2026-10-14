import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// Rounded search field with a clear button and an optional solid filter
/// button showing how many filters are on (Figma: Search Row).
class ShopSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final int filterCount;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear;

  /// Shows the round filter button when set.
  final VoidCallback? onFilter;
  final String hint;
  final Key fieldKey;

  /// When set the field does not take typing; tapping it calls this
  /// (e.g. opens the Search screen).
  final VoidCallback? onTap;

  const ShopSearchBar({
    super.key,
    required this.controller,
    this.filterCount = 0,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.onFilter,
    this.hint = 'Search figures, cards, series...',
    this.fieldKey = const Key('home_search'),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.10), blurRadius: 18, offset: const Offset(0, 6)),
              ],
            ),
            child: TextField(
              key: fieldKey,
              controller: controller,
              readOnly: onTap != null,
              onTap: onTap,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: dark ? scheme.surfaceContainerHigh : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                ),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close_rounded), onPressed: onClear),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
        if (onFilter != null) ...[
          const SizedBox(width: 10),
          Badge(
            isLabelVisible: filterCount > 0,
            label: Text('$filterCount'),
            backgroundColor: AppTheme.coral,
            child: IconButton.filled(
              key: const Key('home_filter'),
              tooltip: 'Filters',
              onPressed: onFilter,
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                foregroundColor: Colors.white,
                fixedSize: const Size(52, 52),
              ),
              icon: const Icon(Icons.tune_rounded),
            ),
          ),
        ],
      ],
    );
  }
}
