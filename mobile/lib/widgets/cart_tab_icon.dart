import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/shop_provider.dart';
import 'cart_drive.dart';

/// Cart icon in the bottom navigation bar with a coral count badge.
/// The add-to-cart cart drives into it, and it squishes when it arrives.
class CartTabIcon extends StatefulWidget {
  final bool selected;

  const CartTabIcon({super.key, this.selected = false});

  @override
  State<CartTabIcon> createState() => _CartTabIconState();
}

class _CartTabIconState extends State<CartTabIcon> {
  final _target = GlobalKey();
  AnimationController? _squish;

  @override
  void initState() {
    super.initState();
    CartDrive.register(_target, () => _squish?.forward(from: 0), priority: 1);
  }

  @override
  void dispose() {
    CartDrive.unregister(_target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = context.watch<ShopProvider>().cartCount;
    return Badge(
      key: Key(widget.selected ? 'tab_cart_badge_selected' : 'tab_cart_badge'),
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppTheme.coral,
      child: Icon(widget.selected ? Icons.shopping_cart_rounded : Icons.shopping_cart_outlined),
    )
        .animate(key: _target, autoPlay: false, onInit: (c) => _squish = c)
        .scale(end: const Offset(1.25, 0.72), alignment: Alignment.bottomCenter, duration: 120.ms, curve: Curves.easeOut)
        .then()
        .scale(end: const Offset(1 / 1.25, 1 / 0.72), alignment: Alignment.bottomCenter, duration: 420.ms, curve: Curves.elasticOut);
  }
}
