import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/admin.dart';
import '../../models/catalog.dart';
import '../../services/admin_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';
import 'admin_widgets.dart';

/// Admin Products tab: search, filters (All, Low stock, Sold out, Hidden),
/// and an In shop switch on each row. Tap a row to edit it.
class AdminProductsScreen extends StatefulWidget {
  final AdminService service;
  final VoidCallback? onChanged;

  const AdminProductsScreen({super.key, required this.service, this.onChanged});

  @override
  State<AdminProductsScreen> createState() => AdminProductsScreenState();
}

class AdminProductsScreenState extends State<AdminProductsScreen> {
  List<AdminProduct>? _items;
  String? _error;
  int _filter = 0;
  String _q = '';

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final items = await widget.service.products();
      if (mounted) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Shows the Low stock list (from the dashboard's count).
  void showLowStock() => setState(() => _filter = 1);

  Future<void> _toggle(AdminProduct p, bool inShop) async {
    try {
      final next = await widget.service.setInShop(p.product.id, inShop);
      if (!mounted) return;
      setState(() => _items = [for (final x in _items!) x.product.id == p.product.id ? next : x]);
      widget.onChanged?.call();
      adminSnack(context, inShop ? '${p.product.name} is back in the shop.' : '${p.product.name} is hidden from the shop.');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    }
  }

  Future<void> _open(AdminProduct p) async {
    final changed = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AdminProductFormScreen(service: widget.service, product: p)));
    if (changed == true) {
      await reload();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final all = _items;
    bool match(AdminProduct p) => switch (_filter) {
          1 => p.isActive && p.product.stock <= 3,
          2 => p.isActive && p.product.stock == 0,
          3 => !p.isActive,
          _ => true,
        };
    int count(int f) {
      final keep = _filter;
      _filter = f;
      final n = all?.where(match).length ?? 0;
      _filter = keep;
      return n;
    }

    final q = _q.trim().toLowerCase();
    final shown = [
      for (final p in all ?? const <AdminProduct>[])
        if (match(p) && (q.isEmpty || p.product.name.toLowerCase().contains(q) || (p.product.brand ?? '').toLowerCase().contains(q))) p,
    ];
    final inShop = all?.where((p) => p.isActive).length ?? 0;
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
          AdminTitle('Products', trailing: all == null ? null : AdminChip('$inShop in shop', scheme.primary)),
          AdminSearch(hint: 'Name or brand', onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 12),
          AdminFilters(
            keyPrefix: 'admin_products_filter',
            items: [('All', all?.length), ('Low stock', count(1)), ('Sold out', count(2)), ('Hidden', count(3))],
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 12),
          if (_error != null && all == null)
            AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: reload)
          else if (all == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (shown.isEmpty)
            const AdminEmpty(icon: Icons.inventory_2_rounded, text: 'No products here.')
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AdminCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final (i, p) in shown.indexed) ...[
                    if (i > 0) Divider(height: 1, indent: 80, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                    InkWell(
                      key: Key('admin_product_${p.product.id}'),
                      onTap: () => _open(p),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(children: [
                          Opacity(
                            opacity: p.isActive ? 1 : 0.45,
                            child: SizedBox(width: 56, height: 56, child: ProductImage(url: p.product.imageUrl, kind: p.product.category.kind, iconSize: 24, borderRadius: BorderRadius.circular(14))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(p.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(p.product.category.name, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                              const SizedBox(height: 4),
                              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                Text(formatPrice(p.product.finalPrice), style: const TextStyle(fontWeight: FontWeight.bold)),
                                if (p.product.discountPrice != null)
                                  Text(formatPrice(p.product.price), style: TextStyle(color: scheme.onSurfaceVariant, decoration: TextDecoration.lineThrough, fontSize: 12)),
                                if (!p.isActive)
                                  AdminChip('Hidden', scheme.onSurfaceVariant)
                                else if (p.product.stock == 0)
                                  const AdminChip('Sold out', AppTheme.danger)
                                else if (p.product.stock <= 3)
                                  AdminChip('${p.product.stock} left', AppTheme.amber)
                                else
                                  Text('${p.product.stock} in stock', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                              ]),
                            ]),
                          ),
                          Switch(key: Key('admin_product_in_shop_${p.product.id}'), value: p.isActive, onChanged: (v) => _toggle(p, v)),
                        ]),
                      ),
                    ),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Add or edit a product: photos (first is the main one), name, category,
/// series, brand, price and sale price, stock, Featured, In the shop.
/// Pops true when something was saved.
class AdminProductFormScreen extends StatefulWidget {
  final AdminService service;
  final AdminProduct? product;

  /// Picks photos (tests pass a fake).
  final Future<List<XFile>> Function()? pickPhotos;

  const AdminProductFormScreen({super.key, required this.service, this.product, this.pickPhotos});

  @override
  State<AdminProductFormScreen> createState() => _AdminProductFormScreenState();
}

class _AdminProductFormScreenState extends State<AdminProductFormScreen> {
  late AdminProduct? _p = widget.product;
  late final _name = TextEditingController(text: _p?.product.name ?? '');
  late final _brand = TextEditingController(text: _p?.product.brand ?? '');
  late final _price = TextEditingController(text: _p == null ? '' : _num(_p!.product.price));
  late final _sale = TextEditingController(text: _p?.product.discountPrice == null ? '' : _num(_p!.product.discountPrice!));
  late final _description = TextEditingController(text: _p?.product.description ?? '');
  late int? _categoryId = _p?.product.category.id;
  late int? _seriesId = _p?.product.series?.id;
  late int _stock = _p?.product.stock ?? 1;
  late bool _featured = _p?.product.isFeatured ?? false;
  late bool _active = _p?.isActive ?? true;
  List<AdminCategory> _categories = const [];
  List<Series> _series = const [];
  final _queued = <XFile>[]; // photos picked before a new product is saved
  Map<String, dynamic> _errors = {};
  String? _error;
  bool _saving = false, _changed = false, _photoBusy = false;

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _price, _sale, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final (cats, series) = await (widget.service.categories(), widget.service.series()).wait;
      if (mounted) {
        setState(() {
          _categories = cats;
          _series = series;
          _categoryId ??= cats.isEmpty ? null : cats.first.id;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load the categories. Pull back and try again.');
    }
  }

  Future<List<XFile>> _pick() => widget.pickPhotos != null ? widget.pickPhotos!() : ImagePicker().pickMultiImage(imageQuality: 90, maxWidth: 1600);

  Future<void> _addPhotos() async {
    final files = await _pick();
    if (files.isEmpty || !mounted) return;
    if (_p == null) return setState(() => _queued.addAll(files));
    setState(() => _photoBusy = true);
    try {
      for (final f in files) {
        _p = await widget.service.uploadPhoto(_p!.product.id, f);
      }
      _changed = true;
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.errors?['file']?.toString() ?? e.message);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto(ProductPhoto photo) async {
    setState(() => _photoBusy = true);
    try {
      _p = await widget.service.deletePhoto(_p!.product.id, photo.id);
      _changed = true;
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  /// A typed price as a number when it is one, else the text (the server explains what's wrong).
  static Object _money(String text) {
    final t = text.trim();
    final v = double.tryParse(t);
    return v != null && v.isFinite ? v : t;
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final fields = <String, dynamic>{
      'name': _name.text.trim(),
      'category_id': _categoryId,
      'series_id': _seriesId,
      'brand': _brand.text.trim(),
      'description': _description.text.trim(),
      'price': _money(_price.text),
      'discount_price': _sale.text.trim().isEmpty ? null : _money(_sale.text),
      'stock': _stock,
      'is_featured': _featured,
      'is_active': _active,
    };
    setState(() {
      _saving = true;
      _errors = {};
      _error = null;
    });
    try {
      var saved = await widget.service.saveProduct(fields, id: _p?.product.id);
      for (final f in _queued) {
        saved = await widget.service.uploadPhoto(saved.product.id, f);
      }
      if (!mounted) return;
      adminSnack(context, widget.product == null ? 'Product added.' : 'Product saved.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _errors = e.errors ?? {};
          _error = e.errors == null ? e.message : 'Please check the fields marked in red.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _hide() async {
    final ok = await showConfirmDialog(
      context,
      icon: const Icon(Icons.visibility_off_rounded, color: AppTheme.danger, size: 30),
      title: 'Hide this product?',
      message: 'Customers will not see it any more. Past orders keep it. You can turn In the shop back on any time.',
      confirmLabel: 'Hide',
      confirmKey: const Key('admin_hide_confirm'),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.service.setInShop(_p!.product.id, false);
      if (!mounted) return;
      adminSnack(context, 'Hidden from the shop.');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    }
  }

  InputDecoration _deco(String label, String key, {String? prefix}) => InputDecoration(
        labelText: label,
        prefixText: prefix,
        errorText: _errors[key]?.toString(),
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final photos = _p?.photos ?? const <ProductPhoto>[];
    Widget photoTile(Widget child, {VoidCallback? onRemove, bool main = false}) => Stack(children: [
          ClipRRect(borderRadius: BorderRadius.circular(18), child: SizedBox(width: 100, height: 100, child: child)),
          if (main)
            Positioned(left: 6, top: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: const Text('Main', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))))),
          if (onRemove != null)
            Positioned(
              right: 4,
              top: 4,
              child: IconButton.filled(
                onPressed: _photoBusy ? null : onRemove,
                tooltip: 'Remove photo',
                style: IconButton.styleFrom(backgroundColor: Colors.black54, minimumSize: const Size(30, 30), fixedSize: const Size(30, 30), padding: EdgeInsets.zero),
                icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
        ]);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            AdminTitle(
              widget.product == null ? 'Add product' : 'Edit product',
              back: true,
              trailing: widget.product == null || !(_p?.isActive ?? false)
                  ? null
                  : IconButton(key: const Key('admin_product_hide'), tooltip: 'Hide from the shop', onPressed: _hide, icon: const Icon(Icons.visibility_off_rounded)),
            ),
            SizedBox(
              height: 104,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                for (final (i, ph) in photos.indexed) ...[
                  photoTile(ProductImage(url: ph.url, kind: ProductKind.figure), main: i == 0, onRemove: () => _removePhoto(ph)),
                  const SizedBox(width: 10),
                ],
                for (final (i, f) in _queued.indexed) ...[
                  photoTile(FutureBuilder(future: f.readAsBytes(), builder: (_, s) => s.hasData ? Image.memory(s.data!, fit: BoxFit.cover) : const ColoredBox(color: Color(0xFFE2E8F0))), main: photos.isEmpty && i == 0, onRemove: () => setState(() => _queued.removeAt(i))),
                  const SizedBox(width: 10),
                ],
                InkWell(
                  key: const Key('admin_product_add_photo'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: _photoBusy ? null : _addPhotos,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: scheme.primary, width: 1.5), color: scheme.primary.withValues(alpha: 0.08)),
                    child: _photoBusy
                        ? const Center(child: CircularProgressIndicator())
                        : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.add_a_photo_rounded, color: scheme.primary),
                            const SizedBox(height: 4),
                            Text('Add photo', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                          ]),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (_error != null) ...[ErrorBanner(message: _error!), const SizedBox(height: 12)],
                TextField(key: const Key('admin_product_name'), controller: _name, inputFormatters: [LengthLimitingTextInputFormatter(150)], textCapitalization: TextCapitalization.words, decoration: _deco('Name', 'name')),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const Key('admin_product_category'),
                      initialValue: _categories.any((c) => c.id == _categoryId) ? _categoryId : null,
                      isExpanded: true,
                      decoration: _deco('Category', 'category_id'),
                      items: [for (final c in _categories) DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))],
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      key: const Key('admin_product_series'),
                      initialValue: _series.any((s) => s.id == _seriesId) ? _seriesId : null,
                      isExpanded: true,
                      decoration: _deco('Series', 'series_id'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('None')),
                        for (final s in _series) DropdownMenuItem<int?>(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis)),
                      ],
                      onChanged: (v) => setState(() => _seriesId = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextField(key: const Key('admin_product_brand'), controller: _brand, inputFormatters: [LengthLimitingTextInputFormatter(100)], decoration: _deco('Brand', 'brand')),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: TextField(key: const Key('admin_product_price'), controller: _price, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(10)], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _deco('Price', 'price', prefix: r'$ '))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(key: const Key('admin_product_sale'), controller: _sale, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), LengthLimitingTextInputFormatter(10)], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: _deco('Sale price', 'discount_price', prefix: r'$ '))),
                ]),
                const SizedBox(height: 12),
                AdminCard(
                  child: Column(children: [
                    Row(children: [
                      const Expanded(child: Text('Stock', style: TextStyle(fontWeight: FontWeight.w600))),
                      QuantityStepper(value: _stock, min: 0, max: 999, keyPrefix: 'admin_product_stock', onChanged: (v) => setState(() => _stock = v)),
                    ]),
                    if (_errors['stock'] != null) Align(alignment: Alignment.centerLeft, child: Text(_errors['stock'].toString(), style: TextStyle(color: scheme.error, fontSize: 12))),
                    const Divider(height: 22),
                    SwitchListTile(key: const Key('admin_product_featured'), contentPadding: EdgeInsets.zero, title: const Text('Featured on Home', style: TextStyle(fontWeight: FontWeight.w600)), value: _featured, onChanged: (v) => setState(() => _featured = v)),
                    SwitchListTile(key: const Key('admin_product_active'), contentPadding: EdgeInsets.zero, title: const Text('In the shop', style: TextStyle(fontWeight: FontWeight.w600)), value: _active, onChanged: (v) => setState(() => _active = v)),
                  ]),
                ),
                const SizedBox(height: 12),
                TextField(key: const Key('admin_product_description'), controller: _description, inputFormatters: [LengthLimitingTextInputFormatter(5000)], minLines: 3, maxLines: 6, decoration: _deco('Description', 'description')),
              ]),
            ),
          ]),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom),
          child: PillButton(key: const Key('admin_product_save'), label: widget.product == null ? 'Add product' : 'Save product', leadingIcon: Icons.check_rounded, loading: _saving, onPressed: _save),
        ),
      ),
    );
  }
}
