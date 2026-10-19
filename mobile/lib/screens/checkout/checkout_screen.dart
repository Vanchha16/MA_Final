import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/order.dart';
import '../../providers/shop_provider.dart';
import '../../services/checkout_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import 'address_form_screen.dart';
import 'address_picker_sheet.dart';
import 'khqr_payment_screen.dart';
import 'order_placed_screen.dart';
import '../../l10n/l10n.dart';

/// Checkout (Figma: Checkout A - One page): deliver to, delivery (Standard
/// or Store pickup), payment (Bakong KHQR or Cash on delivery), the items,
/// an optional note and the order summary, with Place order at the bottom.
///
/// Pops with true when the order was placed (the Cart then forgets its promo code).
class CheckoutScreen extends StatefulWidget {
  /// The promo code applied in the Cart, if any.
  final String? coupon;
  final CheckoutService? service;

  /// For the KHQR screen opened after Place order.
  final PaymentService? paymentService;

  const CheckoutScreen({super.key, this.coupon, this.service, this.paymentService});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late final CheckoutService _service = widget.service ?? CheckoutService();
  late String? _coupon = widget.coupon;
  final _note = TextEditingController();

  CheckoutPreview? _preview;
  String? _error;
  DeliveryMethod _delivery = DeliveryMethod.standard;
  PaymentMethod _payment = PaymentMethod.khqr;
  int? _addressId;
  bool _placing = false;
  bool _showItems = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Address? get _address => _preview?.addresses.where((a) => a.id == _addressId).firstOrNull;

  Future<void> _load() async {
    try {
      final preview = await _service.preview(coupon: _coupon, delivery: _delivery);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _error = null;
        // Keep the chosen address if it still exists, else the default (listed first)
        if (_address == null) _addressId = preview.addresses.firstOrNull?.id;
      });
      final reason = preview.cart.couponError;
      if (reason != null) {
        _snack('$reason. The promo code was removed.');
        _coupon = null;
        await _load();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

  void _setDelivery(DeliveryMethod method) {
    if (method == _delivery) return;
    setState(() => _delivery = method);
    _load(); // pickup has no delivery fee
  }

  Future<void> _addAddress() async {
    final saved = await Navigator.of(context).push<Address>(MaterialPageRoute(builder: (_) => AddressFormScreen(service: _service)));
    if (saved == null || !mounted) return;
    _addressId = saved.id;
    await _load();
  }

  Future<void> _changeAddress() async {
    final picked = await showAddressPicker(context, addresses: _preview!.addresses, selectedId: _addressId, service: _service);
    if (!mounted) return;
    if (picked != null) _addressId = picked.id;
    await _load(); // addresses may have been added or edited
  }

  Future<void> _place() async {
    final preview = _preview!;
    if (_delivery == DeliveryMethod.standard && _address == null) {
      _snack('Add a delivery address first');
      return;
    }
    setState(() => _placing = true);
    try {
      final order = await _service.placeOrder(
        addressId: _addressId,
        delivery: _delivery,
        payment: _payment,
        coupon: preview.cart.coupon?.code,
        note: _note.text,
      );
      if (!mounted) return;
      context.read<ShopProvider>().setCartCount(0);
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => order.paymentMethod.online ? KhqrPaymentScreen(order: order, fromCheckout: true, service: widget.paymentService) : OrderPlacedScreen(order: order),
        ),
        result: true,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final couponProblem = e.errors?['coupon'] as String?;
      if (couponProblem != null) _coupon = null;
      _snack(couponProblem ?? e.message);
      await _load(); // stock or prices may have changed
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    Widget body;
    if (_error != null && preview == null) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
          PillButton(key: const Key('checkout_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
        ]),
      );
    } else if (preview == null) {
      body = const _Loading();
    } else if (preview.cart.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Your cart is empty.', key: const Key('checkout_empty'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
    } else {
      body = ListView(
        key: const Key('checkout_list'),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          if (_delivery == DeliveryMethod.standard) ...[
            const _Label('DELIVER TO'),
            _address == null
                ? _AddAddressCard(onTap: _addAddress)
                : _AddressCard(address: _address!, onChange: _changeAddress),
          ] else ...[
            const _Label('PICK UP AT'),
            _StoreCard(name: preview.storeName, address: preview.storeAddress),
          ],
          const _Label('DELIVERY'),
          // Same height for both cards, even when one detail wraps
          IntrinsicHeight(
            child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, option) in preview.deliveryOptions.indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _DeliveryCard(
                    key: Key('delivery_${option.method.name}'),
                    option: option,
                    selected: option.method == _delivery,
                    onTap: () => _setDelivery(option.method),
                  ),
                ),
              ],
            ],
            ),
          ),
          const _Label('PAYMENT'),
          for (final method in PaymentMethod.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PaymentCard(
                key: Key('pay_${method.name}'),
                method: method,
                pickup: _delivery == DeliveryMethod.pickup,
                selected: method == _payment,
                onTap: () => setState(() => _payment = method),
              ),
            ),
          const _Label('ITEMS'),
          _ItemsCard(preview: preview, expanded: _showItems, onToggle: () => setState(() => _showItems = !_showItems)),
          const SizedBox(height: 10),
          TextField(
            key: const Key('checkout_note'),
            controller: _note,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: _delivery == DeliveryMethod.pickup ? 'Note for the shop (optional)' : 'Note for the rider (optional)',
              prefixIcon: const Icon(Icons.sticky_note_2_outlined),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
          const SizedBox(height: 14),
          _Summary(preview: preview, pickup: _delivery == DeliveryMethod.pickup),
        ],
      );
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(children: [
                const CircleBackButton(),
                const SizedBox(width: 14),
                Text(context.l10n.checkoutTitle, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              ]),
            ),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: preview == null || preview.cart.isEmpty
          ? null
          : _PlaceBar(total: preview.cart.total, placing: _placing, onPlace: _place),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text, style: TextStyle(fontSize: 11, letterSpacing: 0.9, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

/// White rounded card; [selected] draws the brand border.
class _Card extends StatelessWidget {
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const _Card({required this.child, this.selected = false, this.onTap, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Material(
        color: dark ? scheme.surfaceContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: selected ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  static const size = 44.0;

  const _IconTile(this.icon, {required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.5),
      );
}

class _Radio extends StatelessWidget {
  final bool on;
  const _Radio(this.on);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? scheme.primary : Colors.transparent,
        border: on ? null : Border.all(color: scheme.outline, width: 2),
      ),
      child: on ? Center(child: Container(width: 9, height: 9, decoration: BoxDecoration(color: scheme.onPrimary, shape: BoxShape.circle))) : null,
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final VoidCallback onChange;

  const _AddressCard({required this.address, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      onTap: onChange,
      child: Row(children: [
        _IconTile(Icons.location_on_rounded, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${address.label} · ${address.recipientName}',
                key: const Key('checkout_address'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('${address.phone}\n${address.oneLine}', style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant)),
          ]),
        ),
        TextButton(key: const Key('checkout_change_address'), onPressed: onChange, child: const Text('Change', style: TextStyle(fontWeight: FontWeight.bold))),
      ]),
    );
  }
}

class _AddAddressCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddAddressCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      onTap: onTap,
      child: Row(children: [
        _IconTile(Icons.add_location_alt_rounded, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add a delivery address', key: Key('checkout_add_address'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text('Where should we bring your order?', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
      ]),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final String name, address;
  const _StoreCard({required this.name, required this.address});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      child: Row(children: [
        _IconTile(Icons.storefront_rounded, color: scheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, key: const Key('checkout_store'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 2),
            Text('$address\nReady today · open 9:00 - 20:00', style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  final DeliveryOption option;
  final bool selected;
  final VoidCallback onTap;

  const _DeliveryCard({super.key, required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Card(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(option.method == DeliveryMethod.pickup ? Icons.storefront_rounded : Icons.local_shipping_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant),
          const Spacer(),
          _Radio(selected),
        ]),
        const SizedBox(height: 8),
        Text(option.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text('${option.detail} · ${option.fee == 0 ? 'Free' : formatPrice(option.fee)}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final PaymentMethod method;
  final bool selected, pickup;
  final VoidCallback onTap;

  const _PaymentCard({super.key, required this.method, required this.selected, required this.pickup, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detail = switch (method) {
      PaymentMethod.khqr => 'Scan with ABA, ACLEDA, Wing or any bank app',
      PaymentMethod.aba => 'Pay in ABA Mobile, or scan its KHQR',
      PaymentMethod.cod => pickup ? 'Pay at the shop when you pick it up' : 'Pay the rider when your order arrives',
    };
    return _Card(
      selected: selected,
      onTap: onTap,
      child: Row(children: [
        _PaymentLogo(method),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(method.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(detail, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        _Radio(selected),
      ]),
    );
  }
}

/// The payment choice's logo (picked option A): the Bakong mark on Bakong red for
/// KHQR, ABA's round logo for ABA PayWay, a cash icon for cash on delivery.
class _PaymentLogo extends StatelessWidget {
  final PaymentMethod method;

  const _PaymentLogo(this.method);

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final (Color background, Widget child) = switch (method) {
      PaymentMethod.khqr => (AppTheme.bakongRed, Image.asset('assets/payment/bakong.png', key: const Key('pay_logo_khqr'), width: 35, semanticLabel: 'Bakong KHQR')),
      PaymentMethod.aba => (Colors.transparent, Image.asset('assets/payment/aba.png', key: const Key('pay_logo_aba'), width: _size, height: _size, semanticLabel: 'ABA Bank')),
      PaymentMethod.cod => (AppTheme.success.withValues(alpha: 0.13), const Icon(Icons.payments_rounded, color: AppTheme.success, size: 24)),
    };
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(13)),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _ItemsCard extends StatelessWidget {
  final CheckoutPreview preview;
  final bool expanded;
  final VoidCallback onToggle;

  const _ItemsCard({required this.preview, required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = preview.cart.lines;
    final shown = lines.take(3).toList();
    return _Card(
      onTap: onToggle,
      padding: const EdgeInsets.all(12),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Column(children: [
          Row(children: [
            for (final l in shown)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox.square(
                  dimension: 44,
                  child: ProductImage(url: l.product.imageUrl, kind: l.product.category.kind, iconSize: 18, borderRadius: BorderRadius.circular(10)),
                ),
              ),
            if (lines.length > shown.length) Text('+${lines.length - shown.length}', style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${preview.cart.count} ${preview.cart.count == 1 ? 'item' : 'items'}', key: const Key('checkout_items'), style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${lines.length} ${lines.length == 1 ? 'product' : 'products'}', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
            Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: scheme.onSurfaceVariant),
          ]),
          if (expanded) ...[
            const Divider(height: 20),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text('${l.quantity} ×', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(l.product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
                  const SizedBox(width: 8),
                  Text(formatPrice(l.subtotal), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final CheckoutPreview preview;
  final bool pickup;

  const _Summary({required this.preview, required this.pickup});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cart = preview.cart;
    Widget line(String a, String b, {Color? color, Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant))),
            Text(b, key: key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color ?? scheme.onSurface)),
          ]),
        );
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(children: [
        line('Subtotal (${cart.count} ${cart.count == 1 ? 'item' : 'items'})', formatPrice(cart.subtotal)),
        if (cart.coupon != null) line('Promo ${cart.coupon!.code}', '-${formatPrice(cart.discount)}', color: AppTheme.success, key: const Key('checkout_discount')),
        line(pickup ? 'Store pickup' : 'Delivery (Phnom Penh)', cart.shippingFee == 0 ? 'Free' : formatPrice(cart.shippingFee),
            color: cart.shippingFee == 0 ? AppTheme.success : null, key: const Key('checkout_delivery_fee')),
        const SizedBox(height: 8),
        DottedLine(dashColor: scheme.outlineVariant, dashLength: 6, dashGapLength: 5, lineThickness: 1.5),
        const SizedBox(height: 10),
        Row(children: [
          const Expanded(child: Text('Total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
          Text(formatPrice(cart.total), key: const Key('checkout_total'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary)),
        ]),
      ]),
    );
  }
}

class _PlaceBar extends StatelessWidget {
  final double total;
  final bool placing;
  final VoidCallback onPlace;

  const _PlaceBar({required this.total, required this.placing, required this.onPlace});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        boxShadow: [if (!dark) BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
      child: Row(children: [
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Total', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          Text(formatPrice(total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary)),
        ]),
        const SizedBox(width: 16),
        Expanded(
          child: PillButton(key: const Key('checkout_place'), label: context.l10n.placeOrder, leadingIcon: Icons.lock_rounded, loading: placing, onPressed: placing ? null : onPlace),
        ),
      ]),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    Widget bar(double h) => Container(
        height: h, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)));
    return Shimmer.fromColors(
      key: const Key('checkout_loading'),
      enabled: !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
      baseColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE8F1FA),
      highlightColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF7FBFF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        physics: const NeverScrollableScrollPhysics(),
        children: [bar(76), bar(96), bar(70), bar(70), bar(68), bar(150)],
      ),
    );
  }
}
