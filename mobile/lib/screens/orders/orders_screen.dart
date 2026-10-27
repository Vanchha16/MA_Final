import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../helpers/format.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import '../checkout/khqr_payment_screen.dart';
import '../shell/main_shell.dart';
import 'order_actions.dart';
import 'order_details_screen.dart';
import 'widgets/order_tracker.dart';
import '../../l10n/l10n.dart';

/// My orders (picked from the order-history previews, C): orders in progress
/// first, each with a tracker that fills up and a pulsing current step, then
/// past orders. "Got it" finishes the tracker and the order moves down to
/// Past orders.
class OrdersScreen extends StatefulWidget {
  final OrderService? service;
  final PaymentService? paymentService;

  const OrdersScreen({super.key, this.service, this.paymentService});

  /// Time the finished tracker stays before the card moves to Past orders.
  static const moveAfter = Duration(milliseconds: 1300);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrderService _service = widget.service ?? OrderService();
  List<Order> _active = [], _past = [];
  bool _loaded = false;
  String? _error;
  final Set<int> _busy = {};

  /// New list keys after each full load, so the animated lists start fresh.
  int _generation = 0;
  GlobalKey<SliverAnimatedListState> _activeKey = GlobalKey(), _pastKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final orders = await _service.list();
      if (!mounted) return;
      setState(() {
        _active = orders.where((o) => o.stage.active).toList();
        _past = orders.where((o) => !o.stage.active).toList();
        _loaded = true;
        _error = null;
        _generation++;
        _activeKey = GlobalKey();
        _pastKey = GlobalKey();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _open(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(order: order, service: _service, paymentService: widget.paymentService),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _pay(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KhqrPaymentScreen(order: order, service: widget.paymentService),
      ),
    );
    if (mounted) await _load();
  }

  /// "Got it": the tracker finishes, then the card moves to Past orders.
  Future<void> _received(Order order) async {
    setState(() => _busy.add(order.id));
    try {
      final delivered = await _service.received(order.id);
      if (!mounted) return;
      final index = _active.indexWhere((o) => o.id == order.id);
      setState(() {
        _busy.remove(order.id);
        if (index >= 0) _active[index] = delivered;
      });
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      await Future.delayed(reduceMotion ? Duration.zero : OrdersScreen.moveAfter);
      if (!mounted) return;
      final at = _active.indexWhere((o) => o.id == order.id);
      if (at < 0) return;
      final gone = _active.removeAt(at);
      const duration = Duration(milliseconds: 450);
      _activeKey.currentState?.removeItem(
        at,
        (context, animation) => _Leaving(
          animation: animation,
          child: _ActiveCard(order: gone),
        ),
        duration: reduceMotion ? Duration.zero : duration,
      );
      _past.insert(0, gone);
      _pastKey.currentState?.insertItem(0, duration: reduceMotion ? Duration.zero : duration);
      setState(() {});
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _busy.remove(order.id));
      AppToast.error(context, e.message);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget body;
    if (_error != null && !_loaded) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ErrorBanner(message: _error!),
            const SizedBox(height: 12),
            PillButton(key: const Key('orders_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
          ],
        ),
      );
    } else if (!_loaded) {
      body = const _Loading();
    } else if (_active.isEmpty && _past.isEmpty) {
      body = const _Empty();
    } else {
      final firstShow = _generation == 1;
      Widget enter(int i, Widget child) =>
          firstShow ? child.animate(delay: (70 * i).ms).fadeIn(duration: 320.ms).slideY(begin: 0.12, curve: Curves.easeOutCubic) : child;
      body = RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const Key('orders_list'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  _active.isEmpty ? context.l10n.nothingInProgress : context.l10n.inProgress(_active.length),
                  key: const Key('orders_active_title'),
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: _active.isEmpty ? scheme.onSurfaceVariant : null),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverAnimatedList(
                key: _activeKey,
                initialItemCount: _active.length,
                itemBuilder: (context, i, animation) => enter(
                  i,
                  _ActiveCard(
                    key: ValueKey('active_${_active[i].id}'),
                    order: _active[i],
                    delay: firstShow ? Duration(milliseconds: 250 + 140 * i) : Duration.zero,
                    fillOnShow: firstShow,
                    busy: _busy.contains(_active[i].id),
                    onOpen: () => _open(_active[i]),
                    onPay: () => _pay(_active[i]),
                    onReceived: () => _received(_active[i]),
                  ),
                ),
              ),
            ),
            if (_past.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: enter(_active.length, Text(context.l10n.pastOrders, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverAnimatedList(
                key: _pastKey,
                initialItemCount: _past.length,
                itemBuilder: (context, i, animation) => SizeTransition(
                  sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  child: FadeTransition(
                    opacity: animation,
                    child: enter(
                      _active.length + 1 + i,
                      _PastRow(
                        key: ValueKey('past_${_past[i].id}'),
                        order: _past[i],
                        onOpen: () => _open(_past[i]),
                        onBuyAgain: () => OrderActions.buyAgain(context, _past[i]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  const CircleBackButton(),
                  const SizedBox(width: 14),
                  Flexible(child: Text(context.l10n.ordersTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

/// The finished card folding away from In progress.
class _Leaving extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _Leaving({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) => SizeTransition(
    sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeInOutCubic),
    child: FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(animation),
        child: child,
      ),
    ),
  );
}

BoxDecoration _cardDecoration(BuildContext context, {double radius = 20}) {
  final scheme = Theme.of(context).colorScheme;
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: dark ? scheme.surfaceContainer : Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
  );
}

Widget _thumb(OrderLine line, double size) => SizedBox.square(
  dimension: size,
  child: ProductImage(url: line.imageUrl, kind: line.kind, iconSize: size * 0.42, borderRadius: BorderRadius.circular(10)),
);

class _ActiveCard extends StatelessWidget {
  final Order order;
  final Duration delay;
  final bool busy, fillOnShow;
  final VoidCallback? onOpen, onPay, onReceived;

  const _ActiveCard({
    super.key,
    required this.order,
    this.delay = Duration.zero,
    this.busy = false,
    this.fillOnShow = false,
    this.onOpen,
    this.onPay,
    this.onReceived,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (text, color, icon) = orderStatusLine(context, order);
    final lines = order.lines.take(3).toList();
    final more = order.lines.length - lines.length;
    Widget? action;
    if (order.stage == OrderStage.toPay) {
      action = _SmallButton(key: Key('order_pay_${order.id}'), label: 'Pay now', icon: Icons.qr_code_2_rounded, onTap: onPay);
    } else if (order.stage == OrderStage.onTheWay) {
      action = _SmallButton(key: Key('order_received_${order.id}'), label: 'Got it', icon: Icons.check_rounded, busy: busy, onTap: onReceived);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: _cardDecoration(context),
          child: InkWell(
            key: Key('order_${order.id}'),
            borderRadius: BorderRadius.circular(20),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      for (final line in lines) Padding(padding: const EdgeInsets.only(right: 6), child: _thumb(line, 46)),
                      if (more > 0)
                        Text(
                          '+$more',
                          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.onSurfaceVariant),
                        ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            formatPrice(order.total),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: scheme.primary),
                          ),
                          Text(order.number, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OrderTracker(order: order, delay: delay, fillOnShow: fillOnShow),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: Row(
                              key: ValueKey(text),
                              children: [
                                Icon(icon, size: 16, color: color),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    text,
                                    key: Key('order_status_${order.id}'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: action ?? const SizedBox.shrink()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PastRow extends StatelessWidget {
  final Order order;
  final VoidCallback onOpen, onBuyAgain;

  const _PastRow({super.key, required this.order, required this.onOpen, required this.onBuyAgain});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final delivered = order.stage == OrderStage.delivered;
    final color = delivered || order.refunded ? AppTheme.success : (order.refundPending ? AppTheme.amber : scheme.onSurfaceVariant);
    final pill = delivered ? 'Delivered' : (order.refundPending ? 'Refund pending' : (order.refunded ? 'Refunded' : 'Cancelled'));
    final date = order.createdAt == null ? '' : DateFormat('d MMM, HH:mm').format(order.createdAt!.toLocal());
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: _cardDecoration(context, radius: 16),
          child: InkWell(
            key: Key('order_${order.id}'),
            borderRadius: BorderRadius.circular(16),
            onTap: onOpen,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  if (order.lines.isNotEmpty) _thumb(order.lines.first, 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                        Text(
                          '${formatPrice(order.total)} · ${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Container(
                        key: Key('order_pill_${order.id}'),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              delivered || order.refunded ? Icons.check_circle_rounded : (order.refundPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded),
                              size: 13,
                              color: color,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              pill,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SmallButton(key: Key('order_again_${order.id}'), label: 'Buy again', tonal: true, onTap: onBuyAgain),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool tonal, busy;
  final VoidCallback? onTap;

  const _SmallButton({super.key, required this.label, this.icon, this.tonal = false, this.busy = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = tonal ? (dark ? scheme.surfaceContainerHighest : AppTheme.skyTint) : (dark ? scheme.primary : AppTheme.primaryDark);
    final fg = tonal ? scheme.primary : (dark ? scheme.onPrimary : Colors.white);
    return FilledButton(
      onPressed: busy ? null : onTap,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 34),
        fixedSize: const Size.fromHeight(34),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12.5, fontWeight: FontWeight.bold),
      ),
      child: busy
          ? SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[Icon(icon, size: 15), const SizedBox(width: 5)],
                Text(label),
              ],
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          key: const Key('orders_empty'),
          children: [
            const IconCircle(icon: Icons.receipt_long_rounded),
            const SizedBox(height: 18),
            const Text('No orders yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'When you buy a figure, plush or card box, you can follow it here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            PillButton(
              key: const Key('orders_shop'),
              label: 'Start shopping',
              leadingIcon: Icons.storefront_outlined,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
                MainShell.requestedTab.value = 0;
              },
            ),
          ],
        ),
      ),
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
      height: h,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
    );
    return Shimmer.fromColors(
      key: const Key('orders_loading'),
      enabled: !(MediaQuery.maybeDisableAnimationsOf(context) ?? false),
      baseColor: dark ? scheme.surfaceContainerHighest : const Color(0xFFE8F1FA),
      highlightColor: dark ? scheme.surfaceContainerHigh : const Color(0xFFF7FBFF),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        physics: const NeverScrollableScrollPhysics(),
        children: [bar(150), bar(150), bar(150), bar(64), bar(64)],
      ),
    );
  }
}
