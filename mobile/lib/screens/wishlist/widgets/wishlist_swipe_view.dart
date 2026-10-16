import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/catalog.dart';
import '../../../widgets/pill_button.dart';
import '../../../widgets/product_image.dart';
import 'wishlist_parts.dart';

/// Default wishlist view (Figma: Wishlist G - Swipe to decide): one saved
/// item at a time. Swipe right (or tap the cart) to move it to the cart,
/// left to remove it (with Undo), up or the arrow to keep it for later.
class WishlistSwipeView extends StatefulWidget {
  final List<Product> items;

  /// Returns false when it could not be moved (the card comes back).
  final Future<bool> Function(Product product) onMove;

  /// The second argument brings the card back when the customer taps Undo.
  final void Function(Product product, VoidCallback undo) onRemove;
  final ValueChanged<Product> onOpen;

  /// Deals a new deck from what is still saved.
  final VoidCallback onStartOver;

  const WishlistSwipeView({
    super.key,
    required this.items,
    required this.onMove,
    required this.onRemove,
    required this.onOpen,
    required this.onStartOver,
  });

  @override
  State<WishlistSwipeView> createState() => _WishlistSwipeViewState();
}

class _WishlistSwipeViewState extends State<WishlistSwipeView> {
  final _controller = CardSwiperController();

  /// The deck is fixed for this round, even while the wishlist changes under it.
  late final List<Product> _deck = [...widget.items];
  int _index = 0;
  bool _done = false;
  int _moved = 0, _removed = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Product get _current => _deck[_index];

  bool _onSwipe(int previous, int? next, CardSwiperDirection direction) {
    final p = _deck[previous];
    if (direction == CardSwiperDirection.right) {
      if (p.soldOut) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Sold out - it stays in your wishlist'), behavior: SnackBarBehavior.floating));
        return false;
      }
      _moved++;
      widget.onMove(p).then((ok) {
        if (!ok && mounted) setState(() => _moved--);
      });
    } else if (direction == CardSwiperDirection.left) {
      _removed++;
      widget.onRemove(p, () {
        if (!mounted) return;
        _controller.undo();
      });
    }
    setState(() {
      if (next == null) {
        _done = true;
      } else {
        _index = next;
      }
    });
    return true;
  }

  bool _onUndo(int? previous, int current, CardSwiperDirection direction) {
    setState(() {
      _index = current;
      _done = false;
      if (direction == CardSwiperDirection.left) _removed--;
    });
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _finished(context);
    final scheme = Theme.of(context).colorScheme;
    final canMove = !_current.soldOut;

    return Column(
      children: [
        Text('${_index + 1} of ${_deck.length}  ·  swipe to decide', key: const Key('swipe_counter'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        Expanded(
          child: CardSwiper(
            controller: _controller,
            cardsCount: _deck.length,
            numberOfCardsDisplayed: math.min(3, _deck.length),
            backCardOffset: const Offset(0, -26),
            scale: 0.92,
            padding: const EdgeInsets.fromLTRB(28, 34, 28, 12),
            isLoop: false,
            allowedSwipeDirection: const AllowedSwipeDirection.only(left: true, right: true, up: true),
            onSwipe: _onSwipe,
            onUndo: _onUndo,
            cardBuilder: (context, i, dx, dy) => _SwipeCard(key: Key('swipe_card_${_deck[i].id}'), product: _deck[i], dx: dx, onTap: () => widget.onOpen(_deck[i])),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundAction(
                key: const Key('swipe_remove'),
                icon: Icons.close_rounded,
                label: 'Remove',
                size: 64,
                color: AppTheme.danger,
                onTap: () => _controller.swipe(CardSwiperDirection.left),
              ),
              const SizedBox(width: 24),
              _RoundAction(
                key: const Key('swipe_later'),
                icon: Icons.arrow_upward_rounded,
                label: 'Later',
                size: 52,
                onTap: () => _controller.swipe(CardSwiperDirection.top),
              ),
              const SizedBox(width: 24),
              _RoundAction(
                key: const Key('swipe_move'),
                icon: Icons.add_shopping_cart_rounded,
                label: canMove ? 'Move to cart' : 'Sold out',
                size: 64,
                color: AppTheme.primaryDark,
                onTap: canMove ? () => _controller.swipe(CardSwiperDirection.right) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// After the last card: what happened, and a new round with what is left.
  Widget _finished(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final kept = _deck.length - _moved - _removed;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('swipe_done'),
          children: [
            const Icon(Icons.task_alt_rounded, size: 72, color: AppTheme.success),
            const SizedBox(height: 14),
            const Text('All caught up', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              [
                if (_moved > 0) '$_moved moved to cart',
                if (_removed > 0) '$_removed removed',
                if (kept > 0) '$kept kept for later',
              ].join(' · '),
              key: const Key('swipe_summary'),
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            if (widget.items.isNotEmpty) ...[
              const SizedBox(height: 20),
              PillButton(key: const Key('swipe_again'), label: 'Go through again', leadingIcon: Icons.replay_rounded, onPressed: widget.onStartOver),
            ],
          ],
        ),
      ),
    );
  }
}

class _SwipeCard extends StatelessWidget {
  final Product product;

  /// How far the card is dragged sideways (-100 to 100); shows the stamps.
  final int dx;
  final VoidCallback onTap;

  const _SwipeCard({super.key, required this.product, required this.dx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final toCart = (dx / 60).clamp(0.0, 1.0), toRemove = (-dx / 60).clamp(0.0, 1.0);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: dark ? 0 : 0.14), blurRadius: 26, offset: const Offset(0, 10))],
      ),
      child: Material(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 72, borderRadius: BorderRadius.zero),
                    if (p.soldOut) const SoldOutVeil(radius: 0),
                    if (p.onSale && !p.soldOut) Positioned(left: 14, top: 14, child: WishTag('-${p.discountPercent}%', background: AppTheme.coral)),
                    if (p.series != null)
                      Positioned(left: 14, bottom: 14, child: WishTag(p.series!.name, background: Colors.white.withValues(alpha: 0.9), foreground: AppTheme.primaryDark)),
                    Positioned(right: 18, top: 22, child: _Stamp('TO CART', AppTheme.primaryDark, opacity: toCart, angle: 0.2)),
                    Positioned(left: 18, top: 22, child: _Stamp('REMOVE', AppTheme.danger, opacity: toRemove, angle: -0.2)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.brand ?? p.category.name, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: WishPrice(product: p, size: 20)),
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

class _Stamp extends StatelessWidget {
  final String text;
  final Color color;
  final double opacity, angle;

  const _Stamp(this.text, this.color, {required this.opacity, required this.angle});

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: opacity,
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
          ),
        ),
      );
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final double size;

  /// Solid fill; null gives a white button with a grey icon.
  final Color? color;
  final VoidCallback? onTap;

  const _RoundAction({super.key, required this.icon, required this.label, required this.size, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onTap != null;
    final bg = !enabled ? (dark ? scheme.surfaceContainerHighest : const Color(0xFFE2E8F0)) : (color ?? (dark ? scheme.surfaceContainerHigh : Colors.white));
    final fg = !enabled ? scheme.onSurfaceVariant : (color != null ? Colors.white : scheme.onSurfaceVariant);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: label,
          child: Material(
            color: bg,
            shape: const CircleBorder(),
            elevation: enabled ? 3 : 0,
            shadowColor: (color ?? Colors.black).withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox.square(dimension: size, child: Icon(icon, color: fg, size: size * 0.45)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

