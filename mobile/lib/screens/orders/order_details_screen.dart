import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../services/review_service.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import '../../widgets/review_sheet.dart';
import '../checkout/khqr_payment_screen.dart';
import 'order_actions.dart';
import 'receipt_screen.dart';
import 'widgets/order_tracker.dart';

/// One order: the tracker, what to do now (Pay now / Got it), the items,
/// where it goes, how it is paid and the totals. Past orders can be bought again,
/// and each item of a delivered order can be rated.
class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  final OrderService? service;
  final PaymentService? paymentService;
  final ReviewService? reviewService;

  /// Open the review sheet for the first item not rated yet (the "Rate it" notification).
  final bool rateFirst;

  const OrderDetailsScreen({super.key, required this.order, this.service, this.paymentService, this.reviewService, this.rateFirst = false});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late final OrderService _service = widget.service ?? OrderService();
  late Order _order = widget.order;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.rateFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final line = _order.stage == OrderStage.delivered ? _order.lines.where((l) => l.productId != null && l.myRating == null).firstOrNull : null;
        if (line != null && mounted) _rate(line);
      });
    }
  }

  Future<void> _rate(OrderLine line) async {
    final outcome = await showReviewSheet(context,
        productId: line.productId!, productName: line.name, imageUrl: line.imageUrl, kind: line.kind, service: widget.reviewService);
    if (outcome == null || !mounted) return;
    setState(() => _order = _order.copyWith(lines: [
          for (final l in _order.lines) l.productId == line.productId ? l.withRating(outcome.review?.rating) : l,
        ]));
    OrderActions.snack(context, outcome.deleted ? 'Review deleted' : 'Review posted');
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _service.get(_order.id);
      if (mounted) setState(() => _order = fresh);
    } on ApiException catch (e) {
      if (mounted) OrderActions.snack(context, e.message);
    }
  }

  Future<void> _pay() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KhqrPaymentScreen(order: _order, service: widget.paymentService)));
    if (mounted) await _refresh();
  }

  Future<void> _cancel() async {
    final reason = await OrderActions.askToCancel(context, _order);
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final cancelled = await _service.cancel(_order.id, reason: reason.isEmpty ? null : reason);
      if (!mounted) return;
      setState(() => _order = cancelled);
      OrderActions.snack(context, cancelled.refundPending ? 'Order cancelled. Your refund is on its way.' : 'Order cancelled');
    } on ApiException catch (e) {
      if (mounted) OrderActions.snack(context, e.message);
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _received() async {
    setState(() => _busy = true);
    try {
      final delivered = await _service.received(_order.id);
      if (!mounted) return;
      setState(() => _order = delivered);
      OrderActions.snack(context, 'Enjoy your order!');
    } on ApiException catch (e) {
      if (mounted) OrderActions.snack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final scheme = Theme.of(context).colorScheme;
    final (text, color, icon) = orderStatusLine(context, o);
    final date = o.createdAt == null ? '' : DateFormat('d MMM yyyy, HH:mm').format(o.createdAt!.toLocal());
    final pickup = o.deliveryMethod == DeliveryMethod.pickup;

    Widget? bottom;
    if (o.stage == OrderStage.toPay) {
      bottom = PillButton(key: const Key('details_pay'), label: 'Pay ${formatPrice(o.total)} with KHQR', leadingIcon: Icons.qr_code_2_rounded, onPressed: _pay);
    } else if (o.stage == OrderStage.onTheWay) {
      bottom = PillButton(key: const Key('details_received'), label: 'Got it', leadingIcon: Icons.check_rounded, loading: _busy, onPressed: _busy ? null : _received);
    } else if (!o.stage.active) {
      bottom = PillButton(key: const Key('details_again'), label: 'Buy again', leadingIcon: Icons.replay_rounded, onPressed: () => OrderActions.buyAgain(context, o));
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Flexible(child: Text('Order details', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
            ]),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                key: const Key('details_list'),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  _Card(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: o.number));
                                OrderActions.snack(context, 'Order number copied');
                              },
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Flexible(
                                  child: Text(o.number,
                                      key: const Key('details_number'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.copy_rounded, size: 15, color: scheme.onSurfaceVariant),
                              ]),
                            ),
                            Text(date, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ]),
                        ),
                        Text(formatPrice(o.total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: scheme.primary)),
                      ]),
                      const SizedBox(height: 16),
                      if (o.stage != OrderStage.cancelled) OrderTracker(order: o, large: true, delay: const Duration(milliseconds: 150)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(child: Text(text, key: const Key('details_status'), style: TextStyle(fontWeight: FontWeight.w600, color: color))),
                      ]),
                      if (o.stage == OrderStage.cancelled) _CancelInfo(order: o),
                      // Paid orders keep their receipt
                      if (o.paymentStatus == 'paid' && o.stage != OrderStage.cancelled) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ReceiptAction(
                            key: const Key('details_view_receipt'),
                            label: 'View receipt',
                            icon: Icons.receipt_rounded,
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReceiptScreen(order: o))),
                          ),
                        ),
                      ],
                    ]),
                  ),
                  _Section(
                    title: '${o.itemCount} ${o.itemCount == 1 ? 'ITEM' : 'ITEMS'}',
                    child: Column(children: [
                      for (final line in o.lines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(children: [
                            SizedBox.square(
                              dimension: 56,
                              child: ProductImage(url: line.imageUrl, kind: line.kind, iconSize: 24, borderRadius: BorderRadius.circular(12)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(line.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.3)),
                                Text('${formatPrice(line.unitPrice)}  ×  ${line.quantity}', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                                if (line.myRating != null) ...[
                                  const SizedBox(height: 3),
                                  KeyedSubtree(
                                    key: Key('details_my_rating_${line.productId}'),
                                    child: RatingBarIndicator(
                                      rating: line.myRating!.toDouble(),
                                      itemCount: 5,
                                      itemSize: 15,
                                      unratedColor: scheme.outlineVariant,
                                      itemBuilder: (_, _) => const Icon(Icons.star_rounded, color: AppTheme.amber),
                                    ),
                                  ),
                                ],
                              ]),
                            ),
                            if (o.stage == OrderStage.delivered && line.productId != null)
                              line.myRating == null
                                  ? _RateButton(key: Key('details_rate_${line.productId}'), onTap: () => _rate(line))
                                  : Text('Reviewed', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.success))
                            else
                              Text(formatPrice(line.unitPrice * line.quantity), style: const TextStyle(fontWeight: FontWeight.bold)),
                          ]),
                        ),
                    ]),
                  ),
                  _Section(
                    title: pickup ? 'PICK UP AT' : 'DELIVER TO',
                    child: _InfoRow(
                      icon: pickup ? Icons.storefront_rounded : Icons.location_on_rounded,
                      title: pickup ? 'Anime World Shop, Toul Kork' : (o.shippingName ?? ''),
                      body: [o.shippingAddress?.replaceFirst('Store pickup: ', ''), if (o.note != null) 'Note: ${o.note}'].whereType<String>().join('\n'),
                    ),
                  ),
                  _Section(
                    title: 'PAYMENT',
                    child: _InfoRow(
                      icon: switch (o.paymentMethod) {
                        PaymentMethod.khqr => Icons.qr_code_2_rounded,
                        PaymentMethod.aba => Icons.account_balance_rounded,
                        PaymentMethod.cod => Icons.payments_rounded,
                      },
                      title: o.paymentMethod.label,
                      body: switch ((o.paymentStatus, o.stage)) {
                        ('paid', _) => 'Paid',
                        ('refund_pending', _) => 'Paid · refund on its way',
                        ('refunded', _) => 'Refunded',
                        (_, OrderStage.cancelled) => 'Not paid · order cancelled',
                        (_, OrderStage.toPay) => 'Waiting for payment',
                        _ => pickup ? 'Pay at the shop' : 'Pay the rider in USD or riel',
                      },
                    ),
                  ),
                  _Section(
                    title: 'SUMMARY',
                    child: Column(children: [
                      _Money('Subtotal', formatPrice(o.subtotal)),
                      if (o.discount > 0) _Money('Promo ${o.couponCode ?? ''}'.trim(), '-${formatPrice(o.discount)}', color: AppTheme.success),
                      _Money(pickup ? 'Store pickup' : 'Delivery', o.shippingFee == 0 ? 'Free' : formatPrice(o.shippingFee),
                          color: o.shippingFee == 0 ? AppTheme.success : null),
                      const Divider(height: 20),
                      Row(children: [
                        const Expanded(child: Text('Total', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                        Text(formatPrice(o.total), key: const Key('details_total'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: scheme.primary)),
                      ]),
                    ]),
                  ),
                  if (o.canCancel) ...[
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      key: const Key('details_cancel'),
                      onPressed: _busy ? null : _cancel,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel order', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.danger,
                        side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.5)),
                        minimumSize: const Size.fromHeight(50),
                        shape: const StadiumBorder(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('You can cancel until your order ships.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
      bottomNavigationBar: bottom == null
          ? null
          : Padding(padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + MediaQuery.paddingOf(context).bottom), child: bottom),
    );
  }
}

class _RateButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RateButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary.withValues(alpha: 0.1),
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 16, color: AppTheme.amber),
            const SizedBox(width: 4),
            Text('Rate it', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 12.5)),
          ]),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: child,
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
          child: Text(title, style: TextStyle(fontSize: 11, letterSpacing: 0.9, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        _Card(child: child),
      ]);
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title, body;
  const _InfoRow({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
        child: Icon(icon, color: scheme.primary, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          if (body.isNotEmpty) Text(body, style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant)),
        ]),
      ),
    ]);
  }
}

class _Money extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Money(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

/// Who cancelled and why, and where the refund is (paid online orders).
class _CancelInfo extends StatelessWidget {
  final Order order;

  const _CancelInfo({required this.order});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = order;
    final who = switch (o.cancelledBy) {
      'customer' => 'You cancelled this order',
      'shop' => 'The shop cancelled this order',
      'system' => 'Not paid in time, so it was cancelled',
      _ => 'This order was cancelled',
    };
    final refundDate = o.refundedAt == null ? '' : ' on ${DateFormat('d MMM yyyy').format(o.refundedAt!.toLocal())}';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      Text(o.cancelReason == null ? who : '$who · ${o.cancelReason}', key: const Key('details_cancel_info'), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
      if (o.refundPending || o.refunded) ...[
        const SizedBox(height: 12),
        Container(
          key: const Key('details_refund'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (o.refunded ? AppTheme.success : AppTheme.amber).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(o.refunded ? Icons.check_circle_rounded : Icons.hourglass_top_rounded, size: 20, color: o.refunded ? AppTheme.success : AppTheme.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(o.refunded ? 'Refunded' : 'Refund pending', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(
                  o.refunded
                      ? '${formatPrice(o.total)} was sent back to you$refundDate.'
                      : 'The shop sends ${formatPrice(o.total)} back to your ${o.paymentMethod.shortName} account within 3 working days.',
                  style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant),
                ),
              ]),
            ),
          ]),
        ),
      ],
    ]);
  }
}
