import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../helpers/format.dart';
import '../../../models/catalog.dart';
import '../../../widgets/pill_button.dart';
import '../../../widgets/product_image.dart';
import 'wishlist_parts.dart';

/// Select view (Figma: Wishlist D - Select & bulk): tick items (sold-out
/// ones cannot be ticked for the cart), then Remove or Move N to cart.
class WishlistSelectView extends StatefulWidget {
  final List<Product> items;
  final Future<void> Function(List<Product> products) onRemove;
  final Future<bool> Function(List<Product> products) onMove;
  final ValueChanged<Product> onOpen;

  const WishlistSelectView({super.key, required this.items, required this.onRemove, required this.onMove, required this.onOpen});

  @override
  State<WishlistSelectView> createState() => _WishlistSelectViewState();
}

class _WishlistSelectViewState extends State<WishlistSelectView> {
  final Set<int> _picked = {};
  bool _working = false;

  @override
  void didUpdateWidget(WishlistSelectView old) {
    super.didUpdateWidget(old);
    // Forget picks for items that are gone
    _picked.retainAll({for (final p in widget.items) p.id});
  }

  List<Product> get _available => widget.items.where((p) => !p.soldOut).toList();
  List<Product> get _pickedItems => widget.items.where((p) => _picked.contains(p.id)).toList();

  bool? get _allState {
    final available = _available;
    if (_picked.isEmpty) return false;
    return available.every((p) => _picked.contains(p.id)) ? true : null;
  }

  void _toggleAll() => setState(() {
        if (_allState == true) {
          _picked.clear();
        } else {
          _picked.addAll(_available.map((p) => p.id));
        }
      });

  Future<void> _run(Future<void> Function(List<Product>) action) async {
    final picked = _pickedItems;
    if (picked.isEmpty) return;
    setState(() => _working = true);
    try {
      await action(picked);
      if (mounted) setState(_picked.clear);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final picked = _pickedItems;
    final soldOut = widget.items.length - _available.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 24, 4),
          child: Row(
            children: [
              Checkbox(
                key: const Key('select_all'),
                value: _allState,
                tristate: true,
                shape: const CircleBorder(),
                onChanged: _available.isEmpty ? null : (_) => _toggleAll(),
              ),
              Text(picked.isEmpty ? 'Select all' : '${picked.length} selected',
                  key: const Key('select_count'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const Spacer(),
              if (soldOut > 0)
                Flexible(
                  child: Text('Sold-out items can only be removed',
                      textAlign: TextAlign.end, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            key: const Key('select_list'),
            padding: const EdgeInsets.fromLTRB(16, 0, 20, 16),
            itemCount: widget.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = widget.items[i];
              final on = _picked.contains(p.id);
              return _Row(
                key: Key('select_row_${p.id}'),
                product: p,
                picked: on,
                onToggle: () => setState(() => on ? _picked.remove(p.id) : _picked.add(p.id)),
                onOpen: () => widget.onOpen(p),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: BoxDecoration(
            color: dark ? scheme.surfaceContainer : Colors.white,
            boxShadow: [if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 128,
                child: PillButton.danger(
                  key: const Key('select_remove'),
                  label: 'Remove',
                  leadingIcon: Icons.close_rounded,
                  onPressed: picked.isEmpty || _working ? null : () => _run(widget.onRemove),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PillButton(
                  key: const Key('select_move'),
                  label: _moveLabel(picked),
                  leadingIcon: Icons.add_shopping_cart_rounded,
                  onPressed: picked.every((p) => p.soldOut) || _working ? null : () => _run((ps) => widget.onMove(ps)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _moveLabel(List<Product> picked) {
    final movable = picked.where((p) => !p.soldOut).toList();
    if (movable.isEmpty) return 'Move to cart';
    return 'Move ${movable.length} · ${formatPrice(wishTotal(movable))}';
  }
}

class _Row extends StatelessWidget {
  final Product product;
  final bool picked;
  final VoidCallback onToggle, onOpen;

  const _Row({super.key, required this.product, required this.picked, required this.onToggle, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = picked ? (dark ? scheme.primary.withValues(alpha: 0.16) : AppTheme.skyTint) : (dark ? scheme.surfaceContainer : Colors.white);
    final border = picked ? (dark ? scheme.primary : const Color(0xFF7DD3FC)) : (dark ? scheme.outlineVariant : const Color(0xFFE2E8F0));
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            children: [
              Checkbox(value: picked, shape: const CircleBorder(), onChanged: (_) => onToggle()),
              GestureDetector(
                onTap: onOpen,
                child: SizedBox.square(
                  dimension: 64,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 26, borderRadius: BorderRadius.circular(12)),
                      if (p.soldOut) const SoldOutVeil(radius: 12, label: false),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w600, color: p.soldOut ? scheme.onSurfaceVariant : null)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(child: WishPrice(product: p, size: 14)),
                        StockLabel(product: p),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
