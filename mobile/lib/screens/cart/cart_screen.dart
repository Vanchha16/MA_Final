import 'package:dotted_border/dotted_border.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/cart.dart';
import '../../providers/shop_provider.dart';
import '../../services/cart_service.dart';
import '../../services/catalog_service.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_image.dart';
import '../../widgets/quantity_stepper.dart';
import '../auth/login_screen.dart';
import '../shell/main_shell.dart';
import '../shop/shop_actions.dart';

/// Cart tab (Figma: Cart C - Receipt): items with a quantity stepper and
/// swipe-left-to-remove (with Undo), a promo code box, a receipt-style order
/// summary with delivery and savings, and Go to checkout.
class CartScreen extends StatefulWidget {
  final CartService? cartService;
  final CatalogService? catalogService;

  const CartScreen({super.key, this.cartService, this.catalogService});

  /// The applied promo code is remembered on this device until checkout.
  static const couponPrefKey = 'cart_coupon';

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final CartService _service = widget.cartService ?? CartService();
  final _promo = TextEditingController();

  Cart? _cart;
  String? _error;
  String? _coupon;
  String? _promoError;
  bool _applying = false;
  final Set<int> _busyLines = {};
  bool? _signedIn;
  int? _knownCount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shop = context.watch<ShopProvider>();
    if (_signedIn != shop.signedIn) {
      _signedIn = shop.signedIn;
      if (shop.signedIn) {
        _start();
      } else {
        setState(() => _cart = null);
      }
    } else if (shop.signedIn && _knownCount != null && shop.cartCount != _knownCount) {
      // Something was added from another screen
      _load();
    }
  }

  @override
  void dispose() {
    _promo.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      _coupon = (await SharedPreferences.getInstance()).getString(CartScreen.couponPrefKey);
    } catch (_) {
      _coupon = null;
    }
    await _load();
  }

  void _show(Cart cart) {
    if (!mounted) return;
    setState(() {
      _cart = cart;
      _error = null;
      _knownCount = cart.count;
      if (cart.couponError != null) _promoError = cart.couponError;
    });
    context.read<ShopProvider>().setCartCount(cart.count);
  }

  Future<void> _load() async {
    try {
      _show(await _service.get(coupon: _coupon));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _saveCoupon(String? code) async {
    _coupon = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      code == null ? await prefs.remove(CartScreen.couponPrefKey) : await prefs.setString(CartScreen.couponPrefKey, code);
    } catch (_) {
      // Only a convenience
    }
  }

  void _snack(String message, {SnackBarAction? action}) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action, behavior: SnackBarBehavior.floating));

  Future<void> _setQuantity(CartLine line, int quantity) async {
    setState(() => _busyLines.add(line.id));
    try {
      _show(await _service.update(line.id, quantity, coupon: _coupon));
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busyLines.remove(line.id));
    }
  }

  Future<void> _remove(CartLine line) async {
    // Hide it right away; the server answer replaces the list
    setState(() => _cart = _withoutLine(line));
    try {
      _show(await _service.remove(line.id, coupon: _coupon));
      _snack(
        'Removed ${line.product.name}',
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              _show(await _service.add(line.product.id, quantity: line.quantity, coupon: _coupon));
            } on ApiException catch (e) {
              _snack(e.message);
            }
          },
        ),
      );
    } on ApiException catch (e) {
      _snack(e.message);
      await _load();
    }
  }

  Cart _withoutLine(CartLine line) {
    final c = _cart!;
    return Cart(
      lines: c.lines.where((l) => l.id != line.id).toList(),
      count: c.count - line.quantity,
      subtotal: c.subtotal,
      discount: c.discount,
      shippingFee: c.shippingFee,
      freeShippingMin: c.freeShippingMin,
      total: c.total,
      savings: c.savings,
      coupon: c.coupon,
    );
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty your cart?'),
        content: const Text('All items will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            key: const Key('cart_clear_confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('Empty cart'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      _show(await _service.clear());
      await _saveCoupon(null);
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _applyCoupon() async {
    final code = _promo.text.trim();
    if (code.isEmpty) return setState(() => _promoError = 'Enter a promo code');
    FocusScope.of(context).unfocus();
    setState(() {
      _applying = true;
      _promoError = null;
    });
    try {
      final cart = await _service.applyCoupon(code);
      await _saveCoupon(cart.coupon?.code);
      _promo.clear();
      _show(cart);
      _snack('${cart.coupon?.code} applied: you save ${formatPrice(cart.discount)}');
    } on ApiException catch (e) {
      if (mounted) setState(() => _promoError = e.errors?['code'] as String? ?? e.message);
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _removeCoupon() async {
    await _saveCoupon(null);
    setState(() => _promoError = null);
    await _load();
  }

  void _checkout() => _snack('Checkout is the next screen we build');

  @override
  Widget build(BuildContext context) {
    final cart = _cart;
    final signedIn = context.watch<ShopProvider>().signedIn;
    final scheme = Theme.of(context).colorScheme;

    Widget body;
    if (!signedIn) {
      body = _GuestState();
    } else if (_error != null && cart == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            PillButton(key: const Key('cart_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
          ],
        ),
      );
    } else if (cart == null) {
      body = const _LoadingState();
    } else if (cart.isEmpty) {
      body = _EmptyState(onShop: () => MainShell.requestedTab.value = 0);
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          key: const Key('cart_list'),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            for (final line in cart.lines)
              _LineRow(
                key: ValueKey('line_${line.id}'),
                line: line,
                busy: _busyLines.contains(line.id),
                onQuantity: (q) => _setQuantity(line, q),
                onRemove: () => _remove(line),
                onOpen: () => ShopActions.openProduct(context, line.product, catalog: widget.catalogService),
              ),
            const SizedBox(height: 8),
            _PromoBox(
              controller: _promo,
              coupon: cart.coupon,
              error: _promoError,
              applying: _applying,
              onApply: _applyCoupon,
              onRemove: _removeCoupon,
            ),
            const SizedBox(height: 16),
            _Receipt(cart: cart),
          ],
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Shopping Cart', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                        if (cart != null && !cart.isEmpty)
                          Text(
                            '${cart.lines.length} ${cart.lines.length == 1 ? 'product' : 'products'} · ${cart.count} ${cart.count == 1 ? 'item' : 'items'}',
                            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  if (cart != null && !cart.isEmpty)
                    TextButton(
                      key: const Key('cart_clear'),
                      onPressed: _clear,
                      style: TextButton.styleFrom(foregroundColor: AppTheme.coral),
                      child: const Text('Clear'),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: cart == null || cart.isEmpty || !signedIn ? null : _CheckoutBar(cart: cart, onCheckout: _checkout),
    );
  }
}

class _LineRow extends StatelessWidget {
  final CartLine line;
  final bool busy;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove, onOpen;

  const _LineRow({super.key, required this.line, required this.busy, required this.onQuantity, required this.onRemove, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final p = line.product;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final warning = p.soldOut
        ? 'Sold out - remove it to check out'
        : line.quantity > p.stock
            ? 'Only ${p.stock} left - lower the amount'
            : p.stock <= 5
                ? 'Only ${p.stock} left'
                : null;

    return Dismissible(
      key: ValueKey('dismiss_${line.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(18)),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(width: 6),
            Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            GestureDetector(
              onTap: onOpen,
              child: SizedBox.square(
                dimension: 68,
                child: Hero(
                  tag: ProductCard.heroTag(p.id),
                  child: ProductImage(url: p.imageUrl, kind: p.category.kind, iconSize: 28, borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: onOpen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, height: 1.3, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(
                      '${formatPrice(p.finalPrice)}  ×  ${line.quantity}',
                      style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
                    ),
                    if (warning != null)
                      Text(
                        warning,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: line.needsAttention ? AppTheme.danger : (dark ? AppTheme.amber : const Color(0xFFB45309)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Opacity(
              opacity: busy ? 0.5 : 1,
              child: QuantityStepper(
                key: Key('stepper_${line.id}'),
                keyPrefix: 'line_${line.id}',
                value: line.quantity,
                max: line.maxQuantity < line.quantity ? line.quantity : line.maxQuantity,
                compact: true,
                onChanged: busy || p.soldOut ? null : onQuantity,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoBox extends StatelessWidget {
  final TextEditingController controller;
  final AppliedCoupon? coupon;
  final String? error;
  final bool applying;
  final VoidCallback onApply, onRemove;

  const _PromoBox({
    required this.controller,
    required this.coupon,
    required this.error,
    required this.applying,
    required this.onApply,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;

    if (coupon != null) {
      return Container(
        key: const Key('promo_applied'),
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
        decoration: BoxDecoration(color: AppTheme.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(26)),
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined, color: AppTheme.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${coupon!.code}  ·  -${formatPrice(coupon!.discount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success)),
                  Text(coupon!.description, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            IconButton(key: const Key('promo_remove'), tooltip: 'Remove promo code', onPressed: onRemove, icon: const Icon(Icons.close_rounded)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DottedBorder(
          options: RoundedRectDottedBorderOptions(
            radius: const Radius.circular(26),
            dashPattern: const [6, 4],
            strokeWidth: 1.2,
            color: error != null ? AppTheme.danger : scheme.primary.withValues(alpha: 0.45),
            padding: EdgeInsets.zero,
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.local_offer_outlined, color: accent, size: 20),
              Expanded(
                child: TextField(
                  key: const Key('promo_field'),
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onApply(),
                  decoration: const InputDecoration(
                    hintText: 'Promo code',
                    filled: false, // the theme fills fields; the dashed box is the field here
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  ),
                ),
              ),
              TextButton(
                key: const Key('promo_apply'),
                onPressed: applying ? null : onApply,
                child: applying
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text('Apply', style: TextStyle(fontWeight: FontWeight.bold, color: accent)),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(error!, key: const Key('promo_error'), style: const TextStyle(fontSize: 12, color: AppTheme.danger)),
          ),
      ],
    );
  }
}

class _Receipt extends StatelessWidget {
  final Cart cart;

  const _Receipt({required this.cart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? scheme.primary : AppTheme.primaryDark;

    Widget line(String label, String value, {Color? color, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant))),
              Text(value, key: key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? scheme.onSurface)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.08), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ORDER SUMMARY', style: TextStyle(fontSize: 11, letterSpacing: 1, fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          line('Subtotal', formatPrice(cart.subtotal), key: const Key('sum_subtotal')),
          if (cart.discount > 0) line('Discount', '-${formatPrice(cart.discount)}', color: AppTheme.success, key: const Key('sum_discount')),
          line(
            'Delivery (Phnom Penh)',
            cart.shippingFee == 0 ? 'Free' : formatPrice(cart.shippingFee),
            color: cart.shippingFee == 0 ? AppTheme.success : null,
            key: const Key('sum_delivery'),
          ),
          if (cart.toFreeShipping > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'Add ${formatPrice(cart.toFreeShipping)} more for free delivery',
                key: const Key('sum_free_hint'),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent),
              ),
            ),
          const SizedBox(height: 8),
          DottedLine(dashColor: scheme.outlineVariant, dashLength: 6, dashGapLength: 5, lineThickness: 1.5),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(child: Text('Total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              Text(formatPrice(cart.total), key: const Key('sum_total'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: accent)),
            ],
          ),
          if (cart.savings > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: AppTheme.success),
                const SizedBox(width: 6),
                Flexible(
                  child: Text('You save ${formatPrice(cart.savings)} on this order',
                      key: const Key('sum_savings'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final Cart cart;
  final VoidCallback onCheckout;

  const _CheckoutBar({required this.cart, required this.onCheckout});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        boxShadow: [if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              Text(formatPrice(cart.total),
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: dark ? scheme.primary : AppTheme.primaryDark)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 54,
              child: FilledButton(
                key: const Key('cart_checkout'),
                onPressed: cart.canCheckout ? onCheckout : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text('Go to checkout', maxLines: 1, overflow: TextOverflow.ellipsis)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onShop;

  const _EmptyState({required this.onShop});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('cart_empty'),
          children: [
            const IconCircle(icon: Icons.shopping_cart_outlined),
            const SizedBox(height: 18),
            const Text('Your cart is empty', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Find a figure, plush or booster box you love and tap + to add it here.',
                textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            PillButton(key: const Key('cart_shop'), label: 'Start shopping', leadingIcon: Icons.storefront_outlined, onPressed: onShop),
          ],
        ),
      ),
    );
  }
}

class _GuestState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IconCircle(icon: Icons.lock_outline_rounded),
            const SizedBox(height: 18),
            const Text('Log in to see your cart', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Your cart is saved to your account, on every device.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            PillButton(
              key: const Key('cart_login'),
              label: 'Log in',
              leadingIcon: Icons.login_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Widget bar(double w, double h) => Container(width: w, height: h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)));
    return Shimmer.fromColors(
      key: const Key('cart_loading'),
      enabled: !reduceMotion,
      baseColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE8F1FA),
      highlightColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF7FBFF),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                bar(68, 68),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(double.infinity, 14), const SizedBox(height: 8), bar(80, 12)])),
              ]),
            ),
          const SizedBox(height: 12),
          bar(double.infinity, 52),
          const SizedBox(height: 16),
          bar(double.infinity, 180),
        ],
      ),
    );
  }
}
