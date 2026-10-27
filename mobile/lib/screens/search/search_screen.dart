import 'dart:async';

import 'package:flutter/material.dart';
import 'package:substring_highlight/substring_highlight.dart';

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../helpers/format.dart';
import '../../helpers/recent_searches.dart';
import '../../models/catalog.dart';
import '../../services/catalog_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/product_image.dart';
import '../catalog/product_list_screen.dart';
import '../shop/shop_actions.dart';

/// Search (Figma: Search A - Chips + Trending). Before typing: recent
/// searches, popular searches and trending products. While typing: matching
/// products with the typed letters highlighted, search phrases, and
/// "See all N results" which opens the Product List.
class SearchScreen extends StatefulWidget {
  final CatalogService? catalogService;

  const SearchScreen({super.key, this.catalogService});

  /// Curated extras shown after the top series in "Popular searches".
  static const popularExtras = ['Nendoroid', 'Booster box', 'Plush', 'Gundam'];

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  final _field = TextEditingController();
  Timer? _debounce;
  int _request = 0;

  List<String> _recent = [];
  List<String> _popular = SearchScreen.popularExtras;
  List<Product> _trending = [];

  SearchSuggestions? _suggestions;
  bool _loading = false;
  String? _error;

  String get _q => _field.text.trim();

  @override
  void initState() {
    super.initState();
    _loadIdle();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  Future<void> _loadIdle() async {
    final recent = await RecentSearches.load();
    if (mounted) setState(() => _recent = recent);
    try {
      final results = await Future.wait([_catalog.series(), _catalog.trending()]);
      if (!mounted) return;
      final series = (results[0] as List<Series>).take(4).map((s) => s.name);
      setState(() {
        _popular = {...series, ...SearchScreen.popularExtras}.toList();
        _trending = results[1] as List<Product>;
      });
    } catch (_) {
      // Popular and trending are extras: search still works without them
    }
  }

  void _onChanged(String _) {
    setState(() {}); // clear button + idle/typing switch
    _debounce?.cancel();
    if (_q.isEmpty) {
      setState(() {
        _suggestions = null;
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), _suggest);
  }

  Future<void> _suggest() async {
    final q = _q;
    final id = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _catalog.suggestions(q);
      if (mounted && id == _request) setState(() => _suggestions = s);
    } on ApiException catch (e) {
      if (mounted && id == _request) setState(() => _error = e.message);
    } finally {
      if (mounted && id == _request) setState(() => _loading = false);
    }
  }

  /// Opens the full results (sort, filters, grid/list) and remembers the search.
  Future<void> _search(String term) async {
    final q = term.trim();
    if (q.isEmpty) return;
    final recent = await RecentSearches.add(q);
    if (!mounted) return;
    setState(() => _recent = recent);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductListScreen(title: 'Results for "$q"', query: ProductQuery(q: q), catalogService: widget.catalogService),
    ));
  }

  Future<void> _openProduct(Product p) async {
    if (_q.isNotEmpty) {
      final recent = await RecentSearches.add(_q);
      if (mounted) setState(() => _recent = recent);
    }
    if (mounted) ShopActions.openProduct(context, p, catalog: widget.catalogService);
  }

  void _fill(String term) {
    _field.text = term;
    _field.selection = TextSelection.collapsed(offset: term.length);
    _onChanged(term);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 24, 12),
              child: Row(
                children: [
                  CircleBackButton(onPressed: () => Navigator.of(context).maybePop()),
                  const SizedBox(width: 10),
                  Expanded(child: _SearchField(controller: _field, onChanged: _onChanged, onSubmitted: _search, onClear: () => _fill(''))),
                ],
              ),
            ),
            Expanded(child: _q.isEmpty ? _idle(context) : _typing(context)),
          ],
        ),
      ),
    );
  }

  Widget _idle(BuildContext context) {
    return ListView(
      key: const Key('search_idle'),
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
      children: [
        if (_recent.isNotEmpty) ...[
          _SectionTitle(
            'Recent searches',
            action: 'Clear all',
            actionKey: const Key('recent_clear'),
            onAction: () async {
              await RecentSearches.clear();
              if (mounted) setState(() => _recent = []);
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in _recent)
                InputChip(
                  key: Key('recent_$r'),
                  label: Text(r),
                  onPressed: () => _search(r),
                  onDeleted: () async {
                    final next = await RecentSearches.remove(r);
                    if (mounted) setState(() => _recent = next);
                  },
                  deleteButtonTooltipMessage: 'Remove $r',
                  shape: const StadiumBorder(),
                ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        const _SectionTitle('Popular searches'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in _popular)
              ActionChip(key: Key('popular_$p'), label: Text(p), onPressed: () => _search(p), shape: const StadiumBorder()),
          ],
        ),
        if (_trending.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionTitle('Trending now'),
          _Card(
            children: [
              for (final (i, p) in _trending.indexed)
                _ProductRow(
                  key: Key('trending_${p.id}'),
                  product: p,
                  leading: SizedBox(
                    width: 22,
                    child: Text(
                      '${i + 1}',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: i == 0 ? AppTheme.amber : const Color(0xFF94A3B8)),
                    ),
                  ),
                  onTap: () => _openProduct(p),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _typing(BuildContext context) {
    final s = _suggestions;
    final scheme = Theme.of(context).colorScheme;
    if (_error != null) {
      return Padding(padding: const EdgeInsets.all(24), child: ErrorBanner(message: _error!));
    }
    if (s == null) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(strokeWidth: 2.5)));
    }
    if (s.total == 0 && s.keywords.isEmpty) {
      return Padding(
        key: const Key('search_no_match'),
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('No matches for "$_q"', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Check the spelling or try a series like One Piece.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          key: const Key('search_typing'),
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 100),
          children: [
            if (s.products.isNotEmpty) ...[
              const _Label('PRODUCTS'),
              _Card(
                children: [
                  for (final p in s.products)
                    _ProductRow(key: Key('suggest_product_${p.id}'), product: p, highlight: _q, showBrand: true, onTap: () => _openProduct(p)),
                ],
              ),
              const SizedBox(height: 18),
            ],
            if (s.keywords.isNotEmpty) ...[
              const _Label('SEARCHES'),
              _Card(
                children: [
                  for (final k in s.keywords)
                    InkWell(
                      key: Key('suggest_keyword_$k'),
                      onTap: () => _search(k),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 20, color: scheme.onSurfaceVariant),
                            const SizedBox(width: 12),
                            Expanded(
                              // Builder: read the app font from inside the page (RichText does not inherit it)
                              child: Builder(
                                builder: (inner) => SubstringHighlight(
                                  text: k,
                                  term: _q,
                                  textStyle: DefaultTextStyle.of(inner).style.merge(TextStyle(fontSize: 15, color: scheme.onSurface)),
                                  textStyleHighlight: DefaultTextStyle.of(inner)
                                      .style
                                      .merge(TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: scheme.onSurface)),
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Use "$k"',
                              onPressed: () => _fill(k),
                              icon: Icon(Icons.north_west_rounded, size: 18, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
        if (s.total > 0)
          Positioned(
            left: 24,
            right: 24,
            bottom: 16,
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('search_see_all'),
                onPressed: () => _search(_q),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                child: Text('See all ${s.total} ${s.total == 1 ? 'result' : 'results'} for "$_q"', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ),
        if (_loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged, onSubmitted;
  final VoidCallback onClear;

  const _SearchField({required this.controller, required this.onChanged, required this.onSubmitted, required this.onClear});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(26), borderSide: BorderSide(color: scheme.primary, width: 1.5));
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.16), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: TextField(
        key: const Key('search_field'),
        controller: controller,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'Search figures, cards, series...',
          filled: true,
          fillColor: dark ? scheme.surfaceContainerHigh : Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
          prefixIcon: Padding(padding: const EdgeInsets.only(left: 8), child: Icon(Icons.search_rounded, color: scheme.primary)),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(key: const Key('search_clear'), tooltip: 'Clear', icon: const Icon(Icons.close_rounded), onPressed: onClear),
          border: border,
          enabledBorder: border,
          focusedBorder: border,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;

  const _SectionTitle(this.text, {this.action, this.actionKey, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          if (action != null) TextButton(key: actionKey, onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _Card extends StatelessWidget {
  final List<Widget> children;

  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Column(children: children),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  final Widget? leading;
  final String? highlight;
  final bool showBrand;
  final VoidCallback onTap;

  const _ProductRow({super.key, required this.product, this.leading, this.highlight, this.showBrand = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;
    // Merged with the app font: SubstringHighlight draws RichText, which does not inherit it
    final nameStyle = DefaultTextStyle.of(context).style.merge(TextStyle(fontSize: 14, height: 1.35, fontWeight: FontWeight.w500, color: scheme.onSurface));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            SizedBox.square(dimension: 48, child: ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 22, borderRadius: BorderRadius.circular(12))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlight == null)
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: nameStyle.copyWith(fontWeight: FontWeight.w600))
                  else
                    SubstringHighlight(
                      text: p.name,
                      term: highlight,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textStyle: nameStyle,
                      textStyleHighlight: nameStyle.copyWith(fontWeight: FontWeight.bold, color: accent),
                    ),
                  if (showBrand) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${formatPrice(p.finalPrice)}  ·  ${p.brand ?? p.category.name}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (!showBrand) ...[
              const SizedBox(width: 8),
              Text(formatPrice(p.finalPrice), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accent)),
            ],
          ],
        ),
      ),
    );
  }
}
