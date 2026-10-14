import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/shop_provider.dart';
import 'cart_fly.dart';
import 'round_icon_button.dart';

/// Round cart button with a coral badge showing the live cart count.
/// Added products fly into it, and it bounces when they land.
class CartButton extends StatefulWidget {
  final VoidCallback? onPressed;

  const CartButton({super.key, this.onPressed});

  @override
  State<CartButton> createState() => _CartButtonState();
}

class _CartButtonState extends State<CartButton> {
  final _target = GlobalKey();
  AnimationController? _bounce;

  @override
  void initState() {
    super.initState();
    CartFly.register(_target, () => _bounce?.forward(from: 0));
  }

  @override
  void dispose() {
    CartFly.unregister(_target);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = context.watch<ShopProvider>().cartCount;
    return Badge(
      key: const Key('cart_badge'),
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppTheme.coral,
      offset: const Offset(-2, 2),
      child: RoundIconButton(icon: Icons.shopping_cart_outlined, tooltip: 'Cart', onPressed: widget.onPressed),
    )
        .animate(key: _target, autoPlay: false, onInit: (c) => _bounce = c)
        .scaleXY(end: 1.22, duration: 140.ms, curve: Curves.easeOut)
        .then()
        .scaleXY(end: 1 / 1.22, duration: 420.ms, curve: Curves.elasticOut);
  }
}
