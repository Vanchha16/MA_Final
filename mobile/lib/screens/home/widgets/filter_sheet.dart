import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../models/catalog.dart';

/// Product filter (screenshot option A - bigger bottom sheet): sort,
/// category, series, several brands, price range with quick picks and
/// "in stock only". The button shows how many products match, live.
/// Returns the new [ProductQuery], or null if dismissed.
class FilterSheet extends StatefulWidget {
  /// The price slider's top end; at the top it means "no limit".
  static const double maxPrice = 200;

  /// Quick price picks: (label, min, max). null = open end.
  static const pricePicks = <(String, double?, double?)>[
    (r'Under $25', null, 25),
    (r'$25 - $50', 25, 50),
    (r'$50 - $100', 50, 100),
    (r'$100+', 100, null),
  ];

  final ProductQuery query;
  final List<Category> categories;
  final List<Series> series;

  /// Brand chips; the section is hidden when empty.
  final List<String> brands;

  /// Counts the products a query would show, for "Show 12 results".
  final Future<int> Function(ProductQuery query)? countResults;

  const FilterSheet({
    super.key,
    required this.query,
    required this.categories,
    this.series = const [],
    this.brands = const [],
    this.countResults,
  });

  static Future<ProductQuery?> show(
    BuildContext context, {
    required ProductQuery query,
    required List<Category> categories,
    List<Series> series = const [],
    List<String> brands = const [],
    Future<int> Function(ProductQuery query)? countResults,
  }) =>
      showModalBottomSheet<ProductQuery>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        useSafeArea: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: 0.92,
          child: FilterSheet(query: query, categories: categories, series: series, brands: brands, countResults: countResults),
        ),
      );

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ProductSort _sort = widget.query.sort;
  late int? _categoryId = widget.query.categoryId;
  late int? _seriesId = widget.query.seriesId;
  late final Set<String> _brands = {...widget.query.brands};
  late RangeValues _price = RangeValues(widget.query.minPrice ?? 0, widget.query.maxPrice ?? FilterSheet.maxPrice);
  late bool _inStock = widget.query.inStockOnly;
  bool _allSeries = false;

  int? _count;
  Timer? _debounce;
  int _countRequest = 0;

  @override
  void initState() {
    super.initState();
    _recount(immediately: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  double? get _minPrice => _price.start > 0 ? _price.start : null;
  double? get _maxPrice => _price.end < FilterSheet.maxPrice ? _price.end : null;

  ProductQuery get _draft => widget.query.copyWith(
        sort: _sort,
        categoryId: () => _categoryId,
        seriesId: () => _seriesId,
        brands: _brands.toList()..sort(),
        minPrice: () => _minPrice,
        maxPrice: () => _maxPrice,
        inStockOnly: _inStock,
      );

  /// Category, series, brands, price and stock that are on (sort is not a filter).
  int get _onCount =>
      (_categoryId != null ? 1 : 0) +
      (_seriesId != null ? 1 : 0) +
      (_brands.isNotEmpty ? 1 : 0) +
      (_minPrice != null || _maxPrice != null ? 1 : 0) +
      (_inStock ? 1 : 0);

  void _change(VoidCallback update) {
    setState(update);
    _recount();
  }

  void _recount({bool immediately = false}) {
    final count = widget.countResults;
    if (count == null) return;
    _debounce?.cancel();
    _debounce = Timer(immediately ? Duration.zero : const Duration(milliseconds: 300), () async {
      final id = ++_countRequest;
      try {
        final n = await count(_draft);
        if (mounted && id == _countRequest) setState(() => _count = n);
      } catch (_) {
        if (mounted && id == _countRequest) setState(() => _count = null);
      }
    });
  }

  void _reset() => _change(() {
        _sort = ProductSort.newest;
        _categoryId = null;
        _seriesId = null;
        _brands.clear();
        _price = const RangeValues(0, FilterSheet.maxPrice);
        _inStock = false;
      });

  void _apply() => Navigator.of(context).pop(_draft);

  String _priceLabel(double v) => v >= FilterSheet.maxPrice ? '${formatPrice(v)}+' : formatPrice(v);

  bool _isPick(double? min, double? max) => _minPrice == min && _maxPrice == max;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final onCount = _onCount;
    final count = _count;
    final buttonText = count == null
        ? 'Show results'
        : count == 0
            ? 'No matches'
            : 'Show $count ${count == 1 ? 'result' : 'results'}';

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('filter_scroll'),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            children: [
              Row(
                children: [
                  Expanded(child: Text('Filters', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                  if (onCount > 0)
                    Container(
                      key: const Key('filter_on_count'),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.coral, borderRadius: BorderRadius.circular(12)),
                      child: Text('$onCount on', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const _Title('Sort by'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in ProductSort.values)
                    _Pill(key: Key('filter_sort_${s.apiValue}'), label: s.short, selected: _sort == s, onTap: () => _change(() => _sort = s)),
                ],
              ),
              if (widget.categories.isNotEmpty) ...[
                const SizedBox(height: 22),
                const _Title('Category'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(key: const Key('filter_cat_all'), label: 'All', selected: _categoryId == null, onTap: () => _change(() => _categoryId = null)),
                    for (final c in widget.categories)
                      _Pill(key: Key('filter_cat_${c.id}'), label: c.name, selected: _categoryId == c.id, onTap: () => _change(() => _categoryId = c.id)),
                  ],
                ),
              ],
              if (widget.series.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Title(
                  'Series',
                  action: _allSeries ? 'Show less' : 'See all',
                  actionKey: const Key('filter_series_more'),
                  onAction: () => setState(() => _allSeries = !_allSeries),
                ),
                if (_allSeries)
                  Wrap(spacing: 8, runSpacing: 8, children: _seriesPills())
                else
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.series.length + 1,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _seriesPills()[i],
                    ),
                  ),
              ],
              if (widget.brands.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Title('Brand', trailing: _brands.isEmpty ? null : '${_brands.length} selected'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Pill(key: const Key('filter_brand_all'), label: 'All', selected: _brands.isEmpty, onTap: () => _change(_brands.clear)),
                    for (final b in widget.brands)
                      _Pill(
                        key: Key('filter_brand_$b'),
                        label: b,
                        selected: _brands.contains(b),
                        check: true,
                        onTap: () => _change(() => _brands.contains(b) ? _brands.remove(b) : _brands.add(b)),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              _Title('Price', trailing: '${_priceLabel(_price.start)} - ${_priceLabel(_price.end)}'),
              RangeSlider(
                key: const Key('filter_price_slider'),
                values: _price,
                max: FilterSheet.maxPrice,
                divisions: 40,
                labels: RangeLabels(_priceLabel(_price.start), _priceLabel(_price.end)),
                onChanged: (v) => _change(() => _price = v),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (i, (label, min, max)) in FilterSheet.pricePicks.indexed)
                    _Pill(
                      key: Key('filter_price_$i'),
                      label: label,
                      selected: _isPick(min, max),
                      onTap: () => _change(() => _price = _isPick(min, max)
                          ? const RangeValues(0, FilterSheet.maxPrice)
                          : RangeValues(min ?? 0, max ?? FilterSheet.maxPrice)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                key: const Key('filter_in_stock'),
                contentPadding: EdgeInsets.zero,
                title: const Text('In stock only', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: const Text('Hide sold-out items'),
                value: _inStock,
                onChanged: (v) => _change(() => _inStock = v),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: dark ? scheme.surfaceContainer : Colors.white,
            boxShadow: [if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('filter_reset'),
                    onPressed: _reset,
                    style: FilledButton.styleFrom(
                      backgroundColor: dark ? scheme.primaryContainer : AppTheme.skyTint,
                      foregroundColor: dark ? scheme.onPrimaryContainer : AppTheme.primaryDark,
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('filter_apply'),
                    onPressed: count == 0 ? null : _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    child: Text(buttonText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _seriesPills() => [
        _Pill(key: const Key('filter_series_all'), label: 'All', selected: _seriesId == null, onTap: () => _change(() => _seriesId = null)),
        for (final s in widget.series)
          _Pill(key: Key('filter_series_${s.id}'), label: s.name, selected: _seriesId == s.id, onTap: () => _change(() => _seriesId = s.id)),
      ];
}

class _Title extends StatelessWidget {
  final String text;
  final String? trailing;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;

  const _Title(this.text, {this.trailing, this.action, this.actionKey, this.onAction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.primary)),
          if (action != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8), minimumSize: const Size(0, 32)),
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

/// Selectable pill: single choice, or multi choice with a check ([check]).
class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool check;
  final VoidCallback onTap;

  const _Pill({super.key, required this.label, required this.selected, this.check = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelStyle = TextStyle(color: selected ? Colors.white : scheme.onSurface, fontWeight: FontWeight.w600);
    final shape = StadiumBorder(side: BorderSide(color: selected ? Colors.transparent : scheme.primary.withValues(alpha: 0.2)));
    final bg = dark ? scheme.surfaceContainerHigh : Colors.white;
    if (check) {
      return FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primaryDark,
        checkmarkColor: Colors.white,
        backgroundColor: bg,
        labelStyle: labelStyle,
        shape: shape,
      );
    }
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      selectedColor: AppTheme.primaryDark,
      backgroundColor: bg,
      labelStyle: labelStyle,
      shape: shape,
    );
  }
}
