import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../models/catalog.dart';
import '../../../widgets/pill_button.dart';

/// Bottom sheet for category, price range and "in stock only".
/// Returns the new [ProductQuery], or null if dismissed.
class FilterSheet extends StatefulWidget {
  /// The price slider's top end; at the top it means "no limit".
  static const double maxPrice = 200;

  final ProductQuery query;
  final List<Category> categories;

  const FilterSheet({super.key, required this.query, required this.categories});

  static Future<ProductQuery?> show(BuildContext context, {required ProductQuery query, required List<Category> categories}) =>
      showModalBottomSheet<ProductQuery>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => FilterSheet(query: query, categories: categories),
      );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late int? _categoryId = widget.query.categoryId;
  late RangeValues _price = RangeValues(widget.query.minPrice ?? 0, widget.query.maxPrice ?? FilterSheet.maxPrice);
  late bool _inStock = widget.query.inStockOnly;

  void _reset() => setState(() {
        _categoryId = null;
        _price = const RangeValues(0, FilterSheet.maxPrice);
        _inStock = false;
      });

  void _apply() {
    Navigator.of(context).pop(widget.query.copyWith(
      categoryId: () => _categoryId,
      minPrice: () => _price.start > 0 ? _price.start : null,
      maxPrice: () => _price.end < FilterSheet.maxPrice ? _price.end : null,
      inStockOnly: _inStock,
    ));
  }

  String _priceLabel(double v) => v >= FilterSheet.maxPrice ? '${formatPrice(v)}+' : formatPrice(v);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    Widget choice(int? id, String label) {
      final selected = _categoryId == id;
      return ChoiceChip(
        key: Key('filter_cat_${id ?? 'all'}'),
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppTheme.primaryDark,
        labelStyle: TextStyle(color: selected ? Colors.white : scheme.onSurface, fontWeight: FontWeight.w600),
        shape: StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : scheme.primary.withValues(alpha: 0.2))),
        onSelected: (_) => setState(() => _categoryId = id),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Filters', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))),
                TextButton(key: const Key('filter_reset'), onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 12),
            Text('Category', style: title),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [choice(null, 'All'), for (final c in widget.categories) choice(c.id, c.name)],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: Text('Price', style: title)),
                Text('${_priceLabel(_price.start)} - ${_priceLabel(_price.end)}',
                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
              ],
            ),
            RangeSlider(
              values: _price,
              max: FilterSheet.maxPrice,
              divisions: 40,
              labels: RangeLabels(_priceLabel(_price.start), _priceLabel(_price.end)),
              onChanged: (v) => setState(() => _price = v),
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              key: const Key('filter_in_stock'),
              contentPadding: EdgeInsets.zero,
              title: Text('In stock only', style: title),
              subtitle: const Text('Hide sold-out items'),
              value: _inStock,
              onChanged: (v) => setState(() => _inStock = v),
            ),
            const SizedBox(height: 16),
            PillButton(key: const Key('filter_apply'), label: 'Show results', onPressed: _apply),
          ],
        ),
      ),
    );
  }
}
