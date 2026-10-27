import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../l10n/l10n.dart';
import '../../models/catalog.dart';
import '../../services/catalog_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/product_image.dart';
import '../catalog/product_list_screen.dart';
import '../shop/shop_actions.dart';
import 'legal_screen.dart';

/// About (picked from the About previews, B): a collage of real product
/// photos that fades into the page, the logo and version, the categories we
/// sell (tap one to shop it), who made the app, and the legal pages.
class AboutScreen extends StatefulWidget {
  final String version;
  final CatalogService? catalogService;

  const AboutScreen({super.key, this.version = '', this.catalogService});

  /// How many photos the collage shows (three columns of two).
  static const photoCount = 6;

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> with SingleTickerProviderStateMixin {
  late final CatalogService _catalog = widget.catalogService ?? CatalogService();
  late final AnimationController _drift = AnimationController(vsync: this, duration: const Duration(seconds: 2));
  List<Product>? _photos;
  List<Category>? _categories;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // The photo columns keep drifting slowly so the header never looks frozen.
    if (_reduceMotion) {
      _drift.stop();
    } else if (!_drift.isAnimating) {
      _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Each half fails on its own: no photos keeps the tinted tiles, no categories hides the chips.
    try {
      final page = await _catalog.products(const ProductQuery(), perPage: 20);
      final photos = page.items.where((p) => p.imageUrl != null).take(AboutScreen.photoCount).toList();
      if (mounted) setState(() => _photos = photos);
    } on ApiException {
      if (mounted) setState(() => _photos = const []);
    }
    try {
      final categories = await _catalog.categories();
      if (mounted) setState(() => _categories = categories);
    } on ApiException {
      if (mounted) setState(() => _categories = const []);
    }
  }

  static const _categoryIcons = {
    'scale-figures': Icons.emoji_events_rounded,
    'chibi-figures': Icons.face_rounded,
    'prize-figures': Icons.redeem_rounded,
    'plush-merch': Icons.toys_rounded,
    'model-kits': Icons.precision_manufacturing_rounded,
    'tcg-boosters': Icons.style_rounded,
    'tcg-decks': Icons.layers_rounded,
    'tcg-accessories': Icons.inventory_2_rounded,
  };

  /// Placeholder looks while the photos load (or when there are none).
  static const _kinds = [ProductKind.figure, ProductKind.plush, ProductKind.figure, ProductKind.kit, ProductKind.figure, ProductKind.tcg];

  void _openCategory(Category c) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductListScreen(title: c.name, query: ProductQuery(categoryId: c.id), catalogService: widget.catalogService)),
      );

  Widget _enter(Widget child, int ms, {double dy = 24}) =>
      _reduceMotion ? child : child.animate(delay: ms.ms).fadeIn(duration: 450.ms).moveY(begin: dy, end: 0, duration: 500.ms, curve: Curves.easeOutCubic);

  Widget _photo(int i, double height) {
    final photos = _photos ?? const [];
    final p = i < photos.length ? photos[i] : null;
    Widget tile = SizedBox(
      height: height,
      child: ProductImage(url: p?.imageUrl, kind: p?.category.kind ?? _kinds[i], iconSize: 30, borderRadius: BorderRadius.circular(14)),
    );
    if (p != null) {
      tile = GestureDetector(
        key: Key('about_photo_$i'),
        onTap: () => ShopActions.openProduct(context, p, catalog: widget.catalogService),
        child: Semantics(button: true, label: p.name, child: tile),
      );
    }
    if (_reduceMotion) return tile;
    return tile.animate(delay: (70 * i).ms).fadeIn(duration: 600.ms).moveY(begin: 40, end: 0, duration: 600.ms, curve: Curves.easeOutCubic);
  }

  Widget _column(List<Widget> children, double sign) => Expanded(
        child: AnimatedBuilder(
          animation: _drift,
          builder: (_, child) => Transform.translate(offset: Offset(0, sign * 7 * (Curves.easeInOut.transform(_drift.value) * 2 - 1)), child: child),
          child: Column(children: children),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final cardColor = dark ? scheme.surfaceContainer : Colors.white;
    final shadow = dark ? null : [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))];
    final bg = theme.scaffoldBackgroundColor;
    final categories = _categories;

    Widget label(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(6, 18, 6, 8),
          child: Text(text, style: TextStyle(fontSize: 11.5, letterSpacing: 0.8, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant)),
        );
    Widget pill(String text, Color color, {IconData? icon}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: color.withValues(alpha: dark ? 0.2 : 0.12), borderRadius: BorderRadius.circular(20)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 15, color: color), const SizedBox(width: 5)],
            Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5)),
          ]),
        );
    Widget link(String key, IconData icon, Color color, String title, VoidCallback onTap) => ListTile(
          key: Key('about_$key'),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: color, size: 19),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          trailing: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          onTap: onTap,
        );
    void openLegal(String title, List<(String, String)> sections) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => LegalScreen(title: title, sections: sections)));

    final header = SizedBox(
      height: 322,
      child: Stack(children: [
        Positioned(
          top: -10,
          left: 12,
          right: 12,
          height: 310,
          child: ExcludeSemantics(
            excluding: _photos == null,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _column([_photo(0, 170), const SizedBox(height: 8), _photo(1, 120)], -1),
              const SizedBox(width: 8),
              _column([const SizedBox(height: 30), _photo(2, 120), const SizedBox(height: 8), _photo(3, 140)], 1),
              const SizedBox(width: 8),
              _column([_photo(4, 150), const SizedBox(height: 8), _photo(5, 140)], -1),
            ]),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 300,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0.25, 0.8], colors: [bg.withValues(alpha: 0), bg]),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 0,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _reduceMotion
                ? _logo(cardColor)
                : _logo(cardColor).animate(delay: 550.ms).fadeIn(duration: 250.ms).scaleXY(begin: 0.5, end: 1, duration: 600.ms, curve: Curves.easeOutBack),
            const SizedBox(width: 14),
            Expanded(
              child: _enter(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Anime World Shop', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (widget.version.isNotEmpty) KeyedSubtree(key: const Key('about_version'), child: pill('v${widget.version}', scheme.primary)),
                    pill(l.aboutCity, AppTheme.coral, icon: Icons.place_rounded),
                  ]),
                ]),
                850,
              ),
            ),
          ]),
        ),
      ]),
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            header,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 14),
                _enter(Text(l.aboutStory, style: const TextStyle(fontSize: 15, height: 1.5)), 1050),
                if (categories == null || categories.isNotEmpty) ...[
                  _enter(label(l.aboutWeSell), 1250),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final (i, c) in (categories ?? const <Category>[]).indexed)
                      _chip(c, i, cardColor, shadow, scheme),
                  ]),
                ],
                _enter(label(l.aboutMadeByLabel), 1900),
                _enter(
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(22), boxShadow: shadow),
                    child: Row(children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED).withValues(alpha: 0.13), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.school_rounded, color: Color(0xFF7C3AED), size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(l.aboutSchool, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(l.aboutProject, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                        ]),
                      ),
                    ]),
                  ),
                  1950,
                  dy: 36,
                ),
                const SizedBox(height: 12),
                _enter(
                  Material(
                    color: cardColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    clipBehavior: Clip.antiAlias,
                    child: Column(children: [
                      link('licenses', Icons.description_rounded, const Color(0xFF64748B), l.licenses, () {
                        showLicensePage(
                          context: context,
                          applicationName: 'Anime World Shop',
                          applicationVersion: widget.version.isEmpty ? null : widget.version,
                          applicationIcon: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/logo_centered.png', width: 64, height: 64)),
                        );
                      }),
                      Divider(height: 1, indent: 70, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      link('privacy', Icons.privacy_tip_rounded, AppTheme.success, l.privacyPolicy, () {
                        openLegal(l.privacyPolicy, [(l.privacy1t, l.privacy1b), (l.privacy2t, l.privacy2b), (l.privacy3t, l.privacy3b), (l.privacy4t, l.privacy4b)]);
                      }),
                      Divider(height: 1, indent: 70, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                      link('terms', Icons.gavel_rounded, AppTheme.amber, l.termsOfUse, () {
                        openLegal(l.termsOfUse, [(l.terms1t, l.terms1b), (l.terms2t, l.terms2b), (l.terms3t, l.terms3b), (l.terms4t, l.terms4b)]);
                      }),
                    ]),
                  ),
                  2100,
                  dy: 36,
                ),
                const SizedBox(height: 18),
                _enter(
                  Text(l.aboutCredit, key: const Key('about_credit'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.45)),
                  2300,
                ),
              ]),
            ),
          ]),
          const Positioned(left: 20, top: 8, child: CircleBackButton()),
        ]),
      ),
    );
  }

  Widget _logo(Color cardColor) => Container(
        width: 86,
        height: 86,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Image.asset('assets/logo_centered.png', semanticLabel: 'Anime World Shop logo'),
      );

  Widget _chip(Category c, int i, Color cardColor, List<BoxShadow>? shadow, ColorScheme scheme) {
    Widget chip = Material(
      color: cardColor,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('about_category_${c.slug}'),
        onTap: () => _openCategory(c),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_categoryIcons[c.slug] ?? Icons.category_rounded, size: 16, color: scheme.primary),
            const SizedBox(width: 6),
            Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
    chip = DecoratedBox(decoration: ShapeDecoration(shape: const StadiumBorder(), shadows: shadow), child: chip);
    if (_reduceMotion) return chip;
    final delay = (1300 + i * 80).ms;
    return chip.animate(delay: delay).fadeIn(duration: 250.ms).scaleXY(begin: 0.7, end: 1, duration: 450.ms, curve: Curves.easeOutBack);
  }
}
