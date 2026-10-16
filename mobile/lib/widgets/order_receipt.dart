import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/format.dart';
import '../models/order.dart';

/// A till receipt for a paid order: shop name, lines, total, how it was paid,
/// a PAID stamp and a torn paper edge. Always white, also in dark mode.
/// [stamp] is the stamp's 0..1 progress (the KHQR screen animates it).
class OrderReceipt extends StatelessWidget {
  final Order order;
  final DateTime? paidAt;
  final double stamp;

  const OrderReceipt({super.key, required this.order, this.paidAt, this.stamp = 1});

  static const width = 300.0;
  static const _ink = Color(0xFF0F172A), _muted = Color(0xFF64748B), _line = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final at = paidAt ?? order.createdAt;
    final when = at == null ? '' : ' · ${DateFormat('d MMM yyyy, HH:mm').format(at.toLocal())}';
    Widget line(String a, String b, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Text(a, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: _ink))),
            const SizedBox(width: 10),
            Text(b, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? _ink)),
          ]),
        );
    final paper = Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ANIME WORLD SHOP', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: _ink)),
        Text('${order.number}$when', key: const Key('khqr_receipt_number'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: _muted)),
        const Divider(height: 26, color: _line),
        for (final l in order.lines) line('${l.quantity} ×  ${l.name}', formatPrice(l.unitPrice * l.quantity)),
        if (order.discount > 0) line('Promo ${order.couponCode ?? ''}'.trim(), '-${formatPrice(order.discount)}', color: AppTheme.success),
        line(order.deliveryMethod == DeliveryMethod.pickup ? 'Store pickup' : 'Delivery', order.shippingFee == 0 ? 'Free' : formatPrice(order.shippingFee)),
        const Divider(height: 26, color: _line),
        Row(children: [
          const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.w900, color: _ink))),
          Text(formatPrice(order.total), key: const Key('khqr_receipt_total'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
        ]),
        const SizedBox(height: 6),
        Text(order.paymentMethod == PaymentMethod.khqr ? 'Paid by KHQR' : 'Paid in cash on delivery', style: const TextStyle(fontSize: 12, color: _muted)),
        const SizedBox(height: 46), // room for the PAID stamp
        Row(children: [for (var i = 0; i < 22; i++) Expanded(child: Container(height: 1.2, margin: const EdgeInsets.symmetric(horizontal: 2), color: _line))]),
        const SizedBox(height: 10),
        const Text('Thank you for shopping with us!', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
      ]),
    );
    return Stack(clipBehavior: Clip.none, children: [
      CustomPaint(painter: _TornShadow(), child: ClipPath(clipper: TornEdge(), child: paper)),
      Positioned(
        right: 26,
        bottom: 62,
        child: Opacity(
          opacity: stamp.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: stamp,
            child: Transform.rotate(
              angle: -0.25,
              child: Container(
                key: const Key('khqr_paid_stamp'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(border: Border.all(color: AppTheme.success, width: 3), borderRadius: BorderRadius.circular(10)),
                child: const Text('PAID', style: TextStyle(color: AppTheme.success, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3)),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Zig-zag bottom edge, like paper torn off a till roll.
class TornEdge extends CustomClipper<Path> {
  static const tooth = 12.0, depth = 7.0;

  @override
  Path getClip(Size s) {
    final p = Path()
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height - depth);
    var x = s.width;
    var down = true;
    while (x > 0) {
      x -= tooth / 2;
      p.lineTo(x.clamp(0, s.width).toDouble(), down ? s.height : s.height - depth);
      down = !down;
    }
    return p..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Soft shadow that follows the torn edge.
class _TornShadow extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      TornEdge().getClip(size).shift(const Offset(0, 5)),
      Paint()
        ..color = const Color(0xFF0F172A).withValues(alpha: 0.14)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
