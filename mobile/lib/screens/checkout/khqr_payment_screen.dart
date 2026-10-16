import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/network/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format.dart';
import '../../models/order.dart';
import '../../services/payment_service.dart';
import '../../services/receipt_export.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/order_receipt.dart';
import '../../widgets/pill_button.dart';
import '../orders/order_details_screen.dart';
import '../orders/receipt_screen.dart';
import '../shell/main_shell.dart';
import 'order_placed_screen.dart';

/// Pay with KHQR (picked from the KHQR previews: F layout + H receipt).
///
/// Waiting: a KHQR card with the QR, a countdown and how to pay; the app
/// checks the payment every few seconds. Paid: the card slides up into a
/// "printer" and a receipt prints out with a PAID stamp. Expired: the order
/// was cancelled and its items went back in stock.
class KhqrPaymentScreen extends StatefulWidget {
  final Order order;
  final PaymentService? service;

  /// Opened straight after Place order: closing it shows Order placed.
  final bool fromCheckout;

  /// Save receipt (tests pass a fake).
  final ReceiptExport export;

  const KhqrPaymentScreen({super.key, required this.order, this.service, this.fromCheckout = false, this.export = const ReceiptExport()});

  /// How often the app asks the server about the payment.
  static const pollEvery = Duration(seconds: 3);

  /// Length of the "receipt prints out" animation.
  static const printDuration = Duration(milliseconds: 2200);

  @override
  State<KhqrPaymentScreen> createState() => _KhqrPaymentScreenState();
}

class _KhqrPaymentScreenState extends State<KhqrPaymentScreen> with SingleTickerProviderStateMixin {
  late final PaymentService _service = widget.service ?? PaymentService();
  late Order _order = widget.order;
  late final _print = AnimationController(vsync: this, duration: KhqrPaymentScreen.printDuration);
  KhqrPayment? _payment;
  String? _error;
  Timer? _poll, _tick;
  bool _checking = false, _simulating = false, _checkingByHand = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _stopTimers();
    _print.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _poll?.cancel();
    _tick?.cancel();
  }

  Future<void> _start() async {
    try {
      _show(await _service.start(_order.id), animate: false);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Applies a server answer; [animate] plays the receipt when it just got paid.
  void _show((KhqrPayment, Order) result, {bool animate = true}) {
    if (!mounted) return;
    final (payment, order) = result;
    final wasPending = _payment == null || _payment!.status == KhqrStatus.pending;
    setState(() {
      _payment = payment;
      _order = order;
      _error = null;
    });
    if (payment.status == KhqrStatus.pending) {
      _poll ??= Timer.periodic(KhqrPaymentScreen.pollEvery, (_) => _check());
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
      return;
    }
    _stopTimers();
    if (payment.status == KhqrStatus.paid && wasPending) {
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      animate && !reduceMotion ? _print.forward(from: 0) : _print.value = 1;
    }
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {}); // the countdown
    if (_left == Duration.zero) _check(); // the server cancels it
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;
    try {
      _show(await _service.status(_order.id));
    } on ApiException {
      // Try again on the next tick; the screen keeps showing the code
    } finally {
      _checking = false;
    }
  }

  /// "I've paid - check now": the same check, with a spinner on the button.
  Future<void> _checkByHand() async {
    setState(() => _checkingByHand = true);
    await _check();
    if (mounted) setState(() => _checkingByHand = false);
  }

  Future<void> _simulate() async {
    setState(() => _simulating = true);
    try {
      _show(await _service.simulate(_order.id));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  Duration get _left {
    final left = _payment!.expiresAt.difference(DateTime.now().toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (_payment?.status == KhqrStatus.paid) return _continue();
    if (widget.fromCheckout) {
      navigator.pushReplacement(MaterialPageRoute(builder: (_) => OrderPlacedScreen(order: _order)));
    } else {
      navigator.pop();
    }
  }

  void _continue() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainShell.requestedTab.value = 0;
  }

  /// View order: back to the tabs, then this order's details.
  void _viewOrder() {
    final navigator = Navigator.of(context);
    final order = _order;
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute(builder: (_) => OrderDetailsScreen(order: order)));
  }

  @override
  Widget build(BuildContext context) {
    final payment = _payment;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: AnimatedBuilder(
            animation: _print,
            builder: (context, _) {
              final t = _print.value * KhqrPaymentScreen.printDuration.inMilliseconds / 1000;
              final paid = payment?.status == KhqrStatus.paid;
              final expired = payment?.status == KhqrStatus.expired;
              return Column(
                children: [
                  _TopBar(
                    title: expired ? 'Payment' : (paid && t >= 0.45 ? 'Your receipt' : 'Pay with KHQR'),
                    onClose: _close,
                  ),
                  Expanded(
                    child: switch (payment) {
                      null when _error != null => _ErrorState(message: _error!, onRetry: _start),
                      null => const Center(child: CircularProgressIndicator()),
                      KhqrPayment _ when expired => const _ExpiredState(),
                      final KhqrPayment payment => _Printer(
                          t: paid ? t : 0,
                          waiting: _Waiting(
                            payment: payment,
                            left: _left,
                            simulating: _simulating,
                            onSimulate: payment.demo ? _simulate : null,
                          ),
                          paidOrder: paid ? _order : null,
                          paidAt: payment.paidAt,
                          // After the stamp: what happens next, right under the receipt
                          after: paid
                              ? _PaidActions(
                                  onSave: () => exportReceipt(context, widget.export, _order, paidAt: payment.paidAt, share: false),
                                  onViewOrder: _viewOrder,
                                  onContinue: _continue,
                                )
                              : null,
                        ),
                    },
                  ),
                  if (!paid)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: _BottomButton(
                        showDone: expired,
                        checking: _checkingByHand,
                        onCheck: payment == null ? null : _checkByHand,
                        onDone: _continue,
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 0..1 progress of [t] (seconds) between [a] and [b].
double _seg(double t, double a, double b, [Curve curve = Curves.easeInOutCubic]) => curve.transform(((t - a) / (b - a)).clamp(0.0, 1.0));

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _TopBar({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(children: [
          IconButton.filledTonal(key: const Key('khqr_close'), tooltip: 'Close', onPressed: onClose, icon: const Icon(Icons.close_rounded)),
          const SizedBox(width: 12),
          Text(title, key: const Key('khqr_title'), style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ]),
      );
}

/// The waiting KHQR card squashes up into a dark slot, then the receipt
/// slides out of it and gets a PAID stamp. [t] is seconds into the animation.
class _Printer extends StatelessWidget {
  final double t;
  final Widget waiting;
  final Order? paidOrder;
  final DateTime? paidAt;
  final Widget? after;

  const _Printer({required this.t, required this.waiting, this.paidOrder, this.paidAt, this.after});

  @override
  Widget build(BuildContext context) {
    final into = _seg(t, 0, .5, Curves.easeInCubic);
    final slot = _seg(t, .25, .5);
    final print = _seg(t, .55, 1.6, Curves.easeOutCubic);
    final stamp = _seg(t, 1.6, 1.95, Curves.easeOutBack);
    final next = _seg(t, 1.7, 2.1);
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        if (into < 1)
          Positioned.fill(
            top: 4 - 40 * into,
            child: Opacity(
              opacity: (1 - into).clamp(0.0, 1.0),
              child: Transform(
                alignment: Alignment.topCenter,
                transform: Matrix4.diagonal3Values(1 + 0.1 * into, 1 - 0.95 * into, 1),
                child: waiting,
              ),
            ),
          ),
        if (paidOrder != null && slot > 0) ...[
          Positioned.fill(
            top: 13,
            child: SingleChildScrollView(
              key: const Key('khqr_receipt'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(children: [
                ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: print,
                    child: OrderReceipt(order: paidOrder!, paidAt: paidAt, stamp: stamp),
                  ),
                ),
                if (after != null && next > 0)
                  Opacity(opacity: next, child: Transform.translate(offset: Offset(0, 16 * (1 - next)), child: after)),
              ]),
            ),
          ),
          Positioned(
            top: 4,
            child: Opacity(
              opacity: slot,
              child: Container(
                width: 330,
                height: 18,
                decoration: BoxDecoration(color: Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerHighest : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(9)),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Under the printed receipt: confirmed, Save receipt / View order, Continue shopping.
class _PaidActions extends StatelessWidget {
  final VoidCallback onSave, onViewOrder, onContinue;

  const _PaidActions({required this.onSave, required this.onViewOrder, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(children: [
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 20),
          SizedBox(width: 8),
          Flexible(child: Text('Your order is confirmed', key: Key('khqr_confirmed'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 4),
        Text("We're packing it now. We'll tell you when it ships.", textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: ReceiptAction(key: const Key('khqr_save_receipt'), label: 'Save receipt', icon: Icons.download_rounded, onPressed: onSave)),
          const SizedBox(width: 10),
          Expanded(child: ReceiptAction(key: const Key('khqr_view_order'), label: 'View order', icon: Icons.receipt_long_rounded, onPressed: onViewOrder)),
        ]),
        const SizedBox(height: 10),
        PillButton(key: const Key('khqr_done'), label: 'Continue shopping', leadingIcon: Icons.storefront_outlined, onPressed: onContinue),
      ]),
    );
  }
}

class _Waiting extends StatelessWidget {
  final KhqrPayment payment;
  final Duration left;
  final bool simulating;
  final VoidCallback? onSimulate;

  const _Waiting({required this.payment, required this.left, required this.simulating, this.onSimulate});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final total = left.inSeconds;
    final countdown = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
    const amber = Color(0xFFB45309);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(children: [
        Container(
          key: const Key('khqr_card'),
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white, // a QR always sits on white, also in dark mode
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppTheme.primaryDark.withValues(alpha: dark ? 0 : 0.10), blurRadius: 22, offset: const Offset(0, 8))],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            Container(
              height: 46,
              color: const Color(0xFFE11D2A),
              alignment: Alignment.center,
              child: const Text('KHQR', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Anime World Shop', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(formatPrice(payment.amount), key: const Key('khqr_amount'),
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  ]),
                ),
              ]),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Semantics(
                label: 'KHQR code to pay ${formatPrice(payment.amount)}',
                child: QrImageView(key: const Key('khqr_qr'), data: payment.qr, size: 210, padding: EdgeInsets.zero, backgroundColor: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(value: total / 900, strokeWidth: 3, color: AppTheme.amber, backgroundColor: const Color(0xFFFDE68A)),
                ),
                const SizedBox(width: 8),
                Text('Expires in $countdown', key: const Key('khqr_countdown'), style: const TextStyle(fontWeight: FontWeight.bold, color: amber)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onSurfaceVariant)),
          const SizedBox(width: 10),
          Flexible(child: Text('Waiting for your payment...', style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600))),
        ]),
        const SizedBox(height: 16),
        Container(
          width: 300,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: dark ? scheme.surfaceContainer : Colors.white, borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final (n, text) in [
              ('1', 'Open ABA, ACLEDA, Wing or any bank app'),
              ('2', 'Tap Scan and point it at the QR'),
              ('3', 'Check ${formatPrice(payment.amount)} to Anime World Shop, then pay'),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: dark ? scheme.surfaceContainerHighest : AppTheme.skyTint,
                    child: Text(n, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: scheme.primary)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
                ]),
              ),
          ]),
        ),
        if (onSimulate != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            key: const Key('khqr_simulate'),
            onPressed: simulating ? null : onSimulate,
            icon: const Icon(Icons.science_outlined),
            label: const Text('Simulate payment (demo)'),
          ),
        ],
      ]),
    );
  }
}

class _ExpiredState extends StatelessWidget {
  const _ExpiredState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(key: const Key('khqr_expired'), children: [
          Icon(Icons.timer_off_outlined, size: 72, color: scheme.onSurfaceVariant),
          const SizedBox(height: 16),
          const Text('This QR code expired', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('The order was not paid in time, so we cancelled it and put the items back in stock. You can order again any time.',
              textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          ErrorBanner(message: message),
          const SizedBox(height: 12),
          PillButton(key: const Key('khqr_retry'), label: 'Try again', leadingIcon: Icons.refresh_rounded, onPressed: onRetry),
        ]),
      );
}

class _BottomButton extends StatelessWidget {
  final bool showDone, checking;
  final VoidCallback? onCheck;
  final VoidCallback onDone;

  const _BottomButton({required this.showDone, required this.checking, required this.onCheck, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (showDone) {
      return PillButton(key: const Key('khqr_done'), label: 'Back to shop', leadingIcon: Icons.storefront_outlined, onPressed: onDone);
    }
    return PillButton(
      key: const Key('khqr_check'),
      label: "I've paid - check now",
      leadingIcon: Icons.refresh_rounded,
      loading: checking,
      color: Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerHighest : AppTheme.skyTint,
      foregroundColor: scheme.primary,
      onPressed: onCheck,
    );
  }
}
