import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/admin.dart';
import '../../models/catalog.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import '../orders/widgets/order_tracker.dart';
import 'admin_widgets.dart';

/// Admin Orders tab: every order, newest first, with search, status filters
/// (with counts) and a one-tap next step. Tap a card for the details.
class AdminOrdersScreen extends StatefulWidget {
  final AdminService service;

  /// Called after an order moved, so the dashboard numbers refresh.
  final VoidCallback? onChanged;

  const AdminOrdersScreen({super.key, required this.service, this.onChanged});

  @override
  State<AdminOrdersScreen> createState() => AdminOrdersScreenState();
}

class AdminOrdersScreenState extends State<AdminOrdersScreen> {
  static const _filters = [null, 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'];
  List<AdminOrder>? _orders;
  String? _error;
  int _filter = 0;
  String _q = '';
  final _busy = <int>{};

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final orders = await widget.service.orders();
      if (mounted) {
        setState(() {
          _orders = orders;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _replace(AdminOrder o) => setState(() => _orders = [for (final x in _orders ?? const <AdminOrder>[]) x.order.id == o.order.id ? o : x]);

  Future<void> _move(AdminOrder o, String status) async {
    if (status == 'cancelled' && !await confirmCancel(context, o)) return;
    setState(() => _busy.add(o.order.id));
    try {
      final next = await widget.service.setOrderStatus(o.order.id, status);
      // The list row has no items; keep the thumbnail
      _replace(AdminOrder(order: next.order, customerId: next.customerId, customerName: next.customerName, customerEmail: next.customerEmail, phone: next.phone, imageUrl: next.imageUrl ?? o.imageUrl, nextStatuses: next.nextStatuses));
      widget.onChanged?.call();
      if (mounted) adminSnack(context, '${o.order.number} marked ${orderStatusLook(status).$1.toLowerCase()}. The customer was told.');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(o.order.id));
    }
  }

  Future<void> _open(AdminOrder o) async {
    final changed = await Navigator.of(context).push<AdminOrder>(MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: o, service: widget.service)));
    if (changed != null) {
      _replace(AdminOrder(order: changed.order, customerId: changed.customerId, customerName: changed.customerName, customerEmail: changed.customerEmail, phone: changed.phone, imageUrl: o.imageUrl, nextStatuses: changed.nextStatuses));
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _orders;
    final scheme = Theme.of(context).colorScheme;
    final toHandle = all?.where((o) => o.order.status == 'pending' || o.order.status == 'confirmed').length ?? 0;
    int count(String? s) => all?.where((o) => s == null || o.order.status == s).length ?? 0;
    final q = _q.trim().toLowerCase();
    final shown = [
      for (final o in all ?? const <AdminOrder>[])
        if ((_filters[_filter] == null || o.order.status == _filters[_filter]) &&
            (q.isEmpty || o.order.number.toLowerCase().contains(q) || o.customerName.toLowerCase().contains(q) || o.customerEmail.toLowerCase().contains(q)))
          o,
    ];
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: const EdgeInsets.only(bottom: 96), children: [
          AdminTitle('Orders', trailing: toHandle > 0 ? AdminChip('$toHandle to handle', AppTheme.amber) : null),
          AdminSearch(hint: 'Order number or customer', onChanged: (v) => setState(() => _q = v)),
          const SizedBox(height: 12),
          AdminFilters(
            keyPrefix: 'admin_orders_filter',
            items: [('All', count(null)), ('Pending', count('pending')), ('Confirmed', count('confirmed')), ('Shipped', count('shipped')), ('Delivered', count('delivered')), ('Cancelled', count('cancelled'))],
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: 12),
          if (_error != null && all == null)
            AdminEmpty(icon: Icons.cloud_off_rounded, text: _error!, onRetry: reload)
          else if (all == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          else if (shown.isEmpty)
            const AdminEmpty(icon: Icons.receipt_long_rounded, text: 'No orders here.')
          else
            for (final o in shown)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: AdminCard(
                  inkKey: Key('admin_order_${o.order.id}'),
                  onTap: () => _open(o),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    SizedBox(
                      width: 54,
                      height: 54,
                      child: ProductImage(url: o.imageUrl, kind: ProductKind.figure, iconSize: 24, borderRadius: BorderRadius.circular(14)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.order.number, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        Text('${o.customerName} · ${o.order.itemCount} item${o.order.itemCount == 1 ? '' : 's'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                        const SizedBox(height: 5),
                        Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          AdminChip(orderStatusLook(o.order.status).$1, orderStatusLook(o.order.status).$2),
                          Text(_payText(o.order), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11.5)),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(formatPrice(o.order.total), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 8),
                      if (o.nextStatuses.any((s) => s != 'cancelled'))
                        FilledButton(
                          key: Key('admin_order_next_${o.order.id}'),
                          onPressed: _busy.contains(o.order.id) ? null : () => _move(o, o.nextStatuses.firstWhere((s) => s != 'cancelled')),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: const StadiumBorder(),
                            textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 12.5),
                          ),
                          child: Text(nextStepShort(o.nextStatuses.firstWhere((s) => s != 'cancelled'))),
                        )
                      else
                        Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                    ]),
                  ]),
                ),
              ),
        ]),
      ),
    );
  }
}

String _payText(Order o) => o.paymentMethod.online
    ? '${o.paymentMethod.shortName} ${o.paymentStatus == 'paid' ? 'paid' : 'unpaid'}'
    : (o.paymentStatus == 'paid' ? 'Cash paid' : 'Cash');

Future<bool> confirmCancel(BuildContext context, AdminOrder o) async =>
    await showConfirmDialog(
      context,
      icon: const Icon(Icons.cancel_rounded, color: AppTheme.danger, size: 32),
      title: 'Cancel this order?',
      message: '${o.order.number} will be cancelled, its items go back on sale and ${o.customerName} gets a notification.',
      confirmLabel: 'Cancel order',
      confirmKey: const Key('admin_cancel_confirm'),
    ) ??
    false;

/// One order for the shop: tracker, customer (tap to call), items, summary,
/// and the next step at the bottom. Pops with the updated order if it moved.
class AdminOrderDetailScreen extends StatefulWidget {
  final AdminOrder order;
  final AdminService service;

  const AdminOrderDetailScreen({super.key, required this.order, required this.service});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late AdminOrder _o = widget.order;
  bool _loaded = false, _busy = false, _moved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await widget.service.order(widget.order.order.id);
      if (mounted) {
        setState(() {
          _o = o;
          _loaded = true;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _move(String status) async {
    if (status == 'cancelled' && !await confirmCancel(context, _o)) return;
    setState(() => _busy = true);
    try {
      final o = await widget.service.setOrderStatus(_o.order.id, status);
      if (!mounted) return;
      setState(() {
        _o = o;
        _moved = true;
      });
      adminSnack(context, 'Marked ${orderStatusLook(status).$1.toLowerCase()}. The customer was told.');
    } on ApiException catch (e) {
      if (mounted) adminSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _o.order;
    final scheme = Theme.of(context).colorScheme;
    final (statusText, statusColor) = orderStatusLook(o.status);
    final next = _o.nextStatuses.where((s) => s != 'cancelled').firstOrNull;
    final canCancel = _o.nextStatuses.contains('cancelled');
    Widget kv(String k, String v, {bool bold = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(k, style: TextStyle(color: bold ? null : scheme.onSurfaceVariant, fontWeight: bold ? FontWeight.bold : null, fontSize: bold ? 16 : 14))),
            Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w600, fontSize: bold ? 19 : 14, color: color)),
          ]),
        );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_moved ? _o : null);
      },
      child: Scaffold(
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
            AdminTitle(o.number, back: true, trailing: AdminChip(statusText, statusColor)),
            if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: ErrorBanner(message: _error!)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (o.status != 'cancelled')
                  AdminCard(child: OrderTracker(key: ValueKey(o.status), order: o, large: true, fillOnShow: false)),
                const AdminLabel('CUSTOMER'),
                AdminCard(
                  child: Column(children: [
                    Row(children: [
                      CircleAvatar(radius: 22, backgroundColor: const Color(0xFF7C3AED).withValues(alpha: 0.15), child: Text(_initials(_o.customerName), style: const TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.bold))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_o.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(_o.phone?.isNotEmpty == true ? _o.phone! : _o.customerEmail, style: TextStyle(color: scheme.onSurfaceVariant)),
                        ]),
                      ),
                      if (_o.phone?.isNotEmpty == true)
                        IconButton.filledTonal(
                          key: const Key('admin_order_call'),
                          tooltip: 'Call',
                          onPressed: () => launchUrl(Uri(scheme: 'tel', path: _o.phone!.replaceAll(' ', ''))),
                          icon: const Icon(Icons.call_rounded, color: AppTheme.success),
                        ),
                    ]),
                    const Divider(height: 22),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(o.deliveryMethod == DeliveryMethod.pickup ? Icons.storefront_rounded : Icons.location_on_rounded, size: 18, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${o.shippingAddress ?? ''} · ${o.deliveryMethod == DeliveryMethod.pickup ? 'Store pickup' : 'Standard delivery'}', style: const TextStyle(fontSize: 13.5, height: 1.35))),
                    ]),
                    if (o.note?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      Row(children: [Icon(Icons.sticky_note_2_rounded, size: 18, color: scheme.onSurfaceVariant), const SizedBox(width: 8), Expanded(child: Text(o.note!, style: const TextStyle(fontStyle: FontStyle.italic)))]),
                    ],
                  ]),
                ),
                const AdminLabel('ITEMS'),
                AdminCard(
                  child: Column(children: [
                    if (!_loaded && o.lines.isEmpty) const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()),
                    for (final l in o.lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          SizedBox(width: 52, height: 52, child: ProductImage(url: l.imageUrl, kind: l.category?.kind ?? ProductKind.figure, iconSize: 22, borderRadius: BorderRadius.circular(12))),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                              Text('${l.quantity} x ${formatPrice(l.unitPrice)}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5)),
                            ]),
                          ),
                          Text(formatPrice(l.unitPrice * l.quantity), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ]),
                      ),
                    if (o.lines.isNotEmpty) const Divider(height: 22),
                    kv('Subtotal', formatPrice(o.subtotal)),
                    if (o.discount > 0) kv('Promo ${o.couponCode ?? ''}'.trim(), '-${formatPrice(o.discount)}', color: AppTheme.success),
                    kv('Delivery', o.shippingFee == 0 ? 'Free' : formatPrice(o.shippingFee)),
                    kv('${o.paymentMethod.shortName} · ${o.paymentStatus == 'paid' ? 'paid' : 'not paid yet'}', formatPrice(o.total), bold: true, color: scheme.primary),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
        bottomNavigationBar: next == null && !canCancel
            ? null
            : Container(
                padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
                decoration: BoxDecoration(color: adminCardColor(context), boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))]),
                child: Row(children: [
                  if (canCancel)
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('admin_order_cancel'),
                        onPressed: _busy ? null : () => _move('cancelled'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: const StadiumBorder(),
                          foregroundColor: AppTheme.danger,
                          side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
                          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        child: const Text('Cancel', maxLines: 1),
                      ),
                    ),
                  if (canCancel && next != null) const SizedBox(width: 10),
                  if (next != null)
                    Expanded(
                      flex: 2,
                      child: PillButton(
                        key: const Key('admin_order_next'),
                        label: nextStepLong(next),
                        leadingIcon: next == 'shipped' ? Icons.local_shipping_rounded : Icons.check_rounded,
                        loading: _busy,
                        onPressed: () => _move(next),
                      ),
                    ),
                ]),
              ),
      ),
    );
  }
}

String _initials(String name) => name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
