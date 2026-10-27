import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../models/catalog.dart';
import '../../models/order.dart';
import '../../models/shop_notification.dart';
import '../../providers/shop_provider.dart';
import '../../services/notification_service.dart';
import '../../services/order_service.dart';
import '../../services/payment_service.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/circle_back_button.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/icon_circle.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/product_image.dart';
import '../checkout/khqr_payment_screen.dart';
import '../orders/order_actions.dart';
import '../orders/order_details_screen.dart';
import '../../l10n/l10n.dart';

/// Notifications (picked from the notification previews, B): rich cards with
/// the product photo and a button (Track, View order, Rate it, Buy again);
/// offers are a gradient coupon card with Copy. New messages drop in at the
/// top while the screen is open (the bell shakes), Mark all read fades the
/// cards one by one, and a card can be swiped away.
class NotificationsScreen extends StatefulWidget {
  final NotificationService? service;
  final OrderService? orderService;
  final PaymentService? paymentService;

  const NotificationsScreen({super.key, this.service, this.orderService, this.paymentService});

  /// How often the open screen looks for new messages.
  static const checkEvery = Duration(seconds: 20);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationService _service = widget.service ?? NotificationService();
  late final OrderService _orders = widget.orderService ?? OrderService();
  final _listKey = GlobalKey<AnimatedListState>();
  List<ShopNotification> _items = [];
  int _unread = 0;
  bool _loaded = false, _firstShow = true;
  String? _error;
  int? _copied;
  int _shakes = 0;

  /// While "Mark all read" runs, each card waits this long times its position.
  Duration _readStagger = Duration.zero;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(NotificationsScreen.checkEvery, (_) => _checkNew());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _setUnread(int unread) {
    _unread = unread;
    context.read<ShopProvider>().setUnreadNotifications(unread);
  }

  Future<void> _load() async {
    try {
      final (items, unread) = await _service.list();
      if (!mounted) return;
      setState(() {
        _firstShow = !_loaded;
        _items = items;
        _loaded = true;
        _error = null;
        _setUnread(unread);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// New messages slide in at the top and the bell shakes.
  Future<void> _checkNew() async {
    if (!_loaded) return;
    try {
      final (items, unread) = await _service.list();
      if (!mounted) return;
      final known = {for (final n in _items) n.id};
      final fresh = items.where((n) => !known.contains(n.id)).toList();
      setState(() {
        _firstShow = false;
        _setUnread(unread);
        for (final n in fresh.reversed) {
          _items.insert(0, n);
          _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));
        }
        if (fresh.isNotEmpty) _shakes++;
      });
    } on ApiException {
      // Try again next time
    }
  }

  Future<void> _markAllRead() async {
    setState(() {
      _readStagger = const Duration(milliseconds: 110);
      _items = [for (final n in _items) n.read()];
      _setUnread(0);
    });
    try {
      _setUnread(await _service.readAll());
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
      await _load();
    }
  }

  Future<void> _markRead(ShopNotification n) async {
    if (n.isRead) return;
    final i = _items.indexWhere((x) => x.id == n.id);
    if (i >= 0) setState(() => _items[i] = n.read());
    try {
      final unread = await _service.read(n.id);
      if (mounted) setState(() => _setUnread(unread));
    } on ApiException {
      // Shown as read anyway; the next load fixes it
    }
  }

  Future<void> _delete(ShopNotification n) async {
    final i = _items.indexWhere((x) => x.id == n.id);
    if (i < 0) return;
    setState(() {
      _items.removeAt(i);
      // Dismissible already played the slide and collapse
      _listKey.currentState?.removeItem(i, (_, _) => const SizedBox.shrink(), duration: Duration.zero);
    });
    try {
      final unread = await _service.delete(n.id);
      if (mounted) setState(() => _setUnread(unread));
    } on ApiException catch (e) {
      if (!mounted) return;
      AppToast.error(context, e.message);
      await _load();
    }
  }

  Future<void> _copy(ShopNotification n) async {
    await Clipboard.setData(ClipboardData(text: n.promoCode!));
    if (!mounted) return;
    setState(() => _copied = n.id);
    AppToast.success(context, '${n.promoCode} copied - use it at checkout');
    _markRead(n);
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted && _copied == n.id) setState(() => _copied = null);
  }

  /// Opens the order the message is about; the button picks what to do there.
  Future<void> _openOrder(ShopNotification n, {bool buyAgain = false, bool rate = false}) async {
    _markRead(n);
    if (n.orderId == null) return;
    try {
      final order = await _orders.get(n.orderId!);
      if (!mounted) return;
      if (buyAgain) return OrderActions.buyAgain(context, order);
      final navigator = Navigator.of(context);
      if (order.stage == OrderStage.toPay) {
        await navigator.push(MaterialPageRoute(builder: (_) => KhqrPaymentScreen(order: order, service: widget.paymentService)));
      } else {
        await navigator.push(MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(order: order, service: _orders, paymentService: widget.paymentService, rateFirst: rate)));
      }
    } on ApiException catch (e) {
      if (mounted) AppToast.error(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget body;
    if (_error != null && !_loaded) {
      body = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          ErrorBanner(message: _error!),
          const SizedBox(height: 12),
          PillButton(key: const Key('notifications_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: _load),
        ]),
      );
    } else if (!_loaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: _checkNew,
        child: ListView(children: const [SizedBox(height: 120), _Empty()]),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _checkNew,
        child: AnimatedList(
          key: _listKey,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          initialItemCount: _items.length,
          itemBuilder: (context, i, animation) {
            final n = _items[i];
            Widget card = Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Dismissible(
                key: ValueKey('dismiss_${n.id}'),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => _delete(n),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 22),
                  decoration: BoxDecoration(color: AppTheme.danger, borderRadius: BorderRadius.circular(20)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline_rounded, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
                ),
                child: _NotificationCard(
                  key: ValueKey('notification_${n.id}'),
                  notification: n,
                  readDelay: _readStagger * i,
                  copied: _copied == n.id,
                  onTap: () => n.orderId != null ? _openOrder(n) : _markRead(n),
                  onAction: () => _openOrder(n, buyAgain: n.event == NotificationEvent.cancelled, rate: n.event == NotificationEvent.delivered),
                  onCopy: () => _copy(n),
                ),
              ),
            );
            if (_firstShow) {
              card = card.animate(delay: (70 * i).ms).fadeIn(duration: 300.ms).slideX(begin: 0.12, curve: Curves.easeOutCubic);
            }
            // New messages grow in from the top
            return SizeTransition(
              sizeFactor: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: FadeTransition(opacity: animation, child: card),
            );
          },
        ),
      );
    }

    Widget bell = const Icon(Icons.notifications_rounded, color: AppTheme.amber, size: 22);
    if (_shakes > 0 && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      bell = bell.animate(key: ValueKey(_shakes)).shake(hz: 6, rotation: 0.35, duration: 700.ms);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(children: [
              const CircleBackButton(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(
                      child: Text(context.l10n.notificationsTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 6),
                    bell,
                  ]),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      !_loaded ? '' : (_unread > 0 ? context.l10n.newCount(_unread) : context.l10n.allCaughtUp),
                      key: ValueKey(_unread > 0),
                      style: TextStyle(fontSize: 13, color: _unread > 0 ? scheme.onSurfaceVariant : AppTheme.success, fontWeight: _unread > 0 ? null : FontWeight.w600),
                    ),
                  ),
                ]),
              ),
              TextButton.icon(
                key: const Key('notifications_read_all'),
                onPressed: _unread > 0 ? _markAllRead : null,
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(context.l10n.markAllRead, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

/// One message. Order messages show the photo and a button; offers are a coupon.
class _NotificationCard extends StatefulWidget {
  final ShopNotification notification;
  final Duration readDelay;
  final bool copied;
  final VoidCallback onTap, onAction, onCopy;

  const _NotificationCard({
    super.key,
    required this.notification,
    required this.readDelay,
    required this.copied,
    required this.onTap,
    required this.onAction,
    required this.onCopy,
  });

  @override
  State<_NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<_NotificationCard> {
  late bool _read = widget.notification.isRead;

  @override
  void didUpdateWidget(_NotificationCard old) {
    super.didUpdateWidget(old);
    final read = widget.notification.isRead;
    if (read == _read) return;
    // Mark all read: one card after another
    if (read && widget.readDelay > Duration.zero) {
      Future.delayed(widget.readDelay, () {
        if (mounted) setState(() => _read = true);
      });
    } else {
      _read = read;
    }
  }

  static (IconData, Color) _look(NotificationEvent e) => switch (e) {
        NotificationEvent.placed => (Icons.receipt_long_rounded, AppTheme.primaryDark),
        NotificationEvent.paid => (Icons.payments_rounded, AppTheme.success),
        NotificationEvent.confirmed => (Icons.inventory_2_rounded, AppTheme.primaryDark),
        NotificationEvent.shipped => (Icons.local_shipping_rounded, const Color(0xFF7C3AED)),
        NotificationEvent.delivered => (Icons.celebration_rounded, AppTheme.success),
        NotificationEvent.cancelled => (Icons.cancel_rounded, const Color(0xFF64748B)),
        NotificationEvent.welcome || NotificationEvent.promo => (Icons.local_offer_rounded, AppTheme.coral),
        NotificationEvent.news => (Icons.campaign_rounded, AppTheme.primaryDark),
        NotificationEvent.support => (Icons.support_agent_rounded, AppTheme.success),
      };

  static String? _actionLabel(NotificationEvent e) => switch (e) {
        NotificationEvent.placed || NotificationEvent.paid || NotificationEvent.confirmed => 'View order',
        NotificationEvent.shipped => 'Track',
        NotificationEvent.delivered => 'Rate it',
        NotificationEvent.cancelled => 'Buy again',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unread = !_read;
    final ago = timeago.format(n.createdAt.toLocal());
    const fade = Duration(milliseconds: 350);

    if (n.isOffer) {
      return Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(colors: n.event == NotificationEvent.welcome ? const [AppTheme.cardStart, AppTheme.accent] : const [AppTheme.coral, AppTheme.amber]),
          ),
          child: InkWell(
            key: Key('notification_tap_${n.id}'),
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(n.event == NotificationEvent.welcome ? Icons.waving_hand_rounded : Icons.bolt_rounded, color: Colors.white, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(n.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.5))),
                      AnimatedScale(
                        scale: unread ? 1 : 0,
                        duration: fade,
                        child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                      ),
                    ]),
                    Text(n.message, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(n.promoCode!, style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, color: AppTheme.coral)),
                        const SizedBox(width: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          decoration: BoxDecoration(color: widget.copied ? AppTheme.success : AppTheme.coral, borderRadius: BorderRadius.circular(8)),
                          child: InkWell(
                            key: Key('notification_copy_${n.id}'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: widget.onCopy,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: widget.copied
                                    ? const Row(key: ValueKey('copied'), mainAxisSize: MainAxisSize.min, children: [
                                        Icon(Icons.check_rounded, color: Colors.white, size: 14),
                                        SizedBox(width: 3),
                                        Text('Copied', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ])
                                    : const Text('Copy', key: ValueKey('copy'), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    final (icon, color) = _look(n.event);
    final action = _actionLabel(n.event);
    final idle = dark ? scheme.surfaceContainer : Colors.white;
    final tint = dark ? scheme.primary.withValues(alpha: 0.16) : AppTheme.skyTint;
    return Material(
      color: Colors.transparent,
      child: AnimatedContainer(
        duration: fade,
        decoration: BoxDecoration(
          color: unread ? tint : idle,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [if (!dark) BoxShadow(color: AppTheme.primaryDark.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 5))],
        ),
        child: InkWell(
          key: Key('notification_tap_${n.id}'),
          borderRadius: BorderRadius.circular(20),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.13), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(n.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: unread ? FontWeight.bold : FontWeight.w600, fontSize: 14.5)),
                ),
                const SizedBox(width: 6),
                Text(ago, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 6),
                AnimatedScale(
                  scale: unread ? 1 : 0,
                  duration: fade,
                  curve: Curves.easeInBack,
                  child: Container(key: Key('notification_dot_${n.id}'), width: 9, height: 9, decoration: const BoxDecoration(color: AppTheme.coral, shape: BoxShape.circle)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (n.orderId != null) ...[
                  SizedBox.square(
                    dimension: 56,
                    child: ProductImage(url: n.imageUrl, kind: ProductKind.figure, iconSize: 24, borderRadius: BorderRadius.circular(12)),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(child: Text(n.message, style: TextStyle(fontSize: 13, height: 1.35, color: scheme.onSurfaceVariant))),
                if (action != null) ...[
                  const SizedBox(width: 8),
                  FilledButton(
                    key: Key('notification_action_${n.id}'),
                    onPressed: widget.onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: dark ? scheme.primary : AppTheme.primaryDark,
                      foregroundColor: dark ? scheme.onPrimary : Colors.white,
                      minimumSize: const Size(0, 32),
                      fixedSize: const Size.fromHeight(32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: const StadiumBorder(),
                      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                    child: Text(action),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(key: const Key('notifications_empty'), children: [
          const IconCircle(icon: Icons.notifications_none_rounded),
          const SizedBox(height: 18),
          const Text('No notifications yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text("We'll tell you here when your orders move or a deal starts.",
              textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}
